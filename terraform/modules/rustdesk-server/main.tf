# -----------------------------------------------------------------------------
# rustdesk-server Module — hbbs + hbbr on a single ARM instance
# -----------------------------------------------------------------------------

# Ubuntu 24.04 ARM64 AMI (Canonical official account)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Shared key in SSM Parameter Store (SecureString) — fetched at boot, never in user_data
resource "aws_ssm_parameter" "key" {
  name  = "/${var.project_name}/${var.environment}/rustdesk/key"
  type  = "SecureString"
  value = var.rustdesk_key

  tags = {
    Name = "${var.project_name}-${var.environment}-rustdesk-key"
  }
}

# --- IAM: SSM Session Manager (admin) + read the key parameter ---

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.project_name}-${var.environment}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
}

resource "aws_iam_role_policy" "read_key" {
  name = "read-rustdesk-key"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = [aws_ssm_parameter.key.arn]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project_name}-${var.environment}-instance-profile"
  role = aws_iam_role.instance.name
}

# --- Security group: relay ports public, SSH opt-in ---

resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "RustDesk relay — 21115-21117 public, admin SSH optional"
  vpc_id      = var.vpc_id

  ingress {
    description = "hbbs NAT type test"
    from_port   = 21115
    to_port     = 21115
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "hbbs ID registration + rendezvous"
    from_port   = 21116
    to_port     = 21116
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "hbbs heartbeat"
    from_port   = 21116
    to_port     = 21116
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "hbbr relay"
    from_port   = 21117
    to_port     = 21117
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.admin_ssh_cidrs
    content {
      description = "admin SSH (opt-in)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg"
  }
}

# --- Instance ---

resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  # EIP provides public access; do not auto-assign a throwaway public IP
  associate_public_ip_address = false

  # IMDSv2 required — blocks SSRF credential theft
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    key_param  = aws_ssm_parameter.key.name
    region     = var.aws_region
    relay_host = var.relay_host
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-instance"
  }
}

# --- Elastic IP ---

resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}
