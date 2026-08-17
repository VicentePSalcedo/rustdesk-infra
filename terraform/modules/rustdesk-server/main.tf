# -----------------------------------------------------------------------------
# rustdesk-server Module — RustDesk Server Pro (hbbs + hbbr, host networking)
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

# --- IAM: SSM Session Manager (admin access, no SSH) ---

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
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project_name}-${var.environment}-instance-profile"
  role = aws_iam_role.instance.name
}

# --- Security group: RustDesk Server Pro ports 21114-21119 public, SSH opt-in ---

resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "RustDesk Server Pro - 21114-21119 public, admin SSH optional"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP (Caddy: HTTPS redirect + ACME challenge)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (Caddy web console)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "web console"
    from_port   = 21114
    to_port     = 21114
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  ingress {
    description = "web client (hbbs)"
    from_port   = 21118
    to_port     = 21118
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "web client (hbbr)"
    from_port   = 21119
    to_port     = 21119
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
    domain = var.domain_name
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
