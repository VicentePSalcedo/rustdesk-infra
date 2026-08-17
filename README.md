# rustdesk-infra

Self-hosted RustDesk **Server Pro** (hbbs + hbbr) on AWS, managed as Terraform.

**Design goals:** minimal footprint, secure by default, zero-touch provisioning.

## Architecture

- **One `t4g.micro` (ARM) instance** running hbbs + hbbr (Server Pro image)
- **Dedicated VPC** (`10.20.0.0/24`), single public subnet, **no NAT gateway**
- **No SSH** — admin access via AWS SSM Session Manager (IAM, no keys, no port 22)
- **Security group** exposes `21114`–`21119` TCP + `21116` UDP
- **Web console** on `21114` for license, users, devices, access control
- **Elastic IP** for a stable public address; **IMDSv2** enforced; encrypted gp3 EBS

```
public internet
      │
      ▼  EIP (remote.artoriastechlab.com)
  ┌───────────────┐  SG: 21114-21119/tcp, 21116/udp
  │ t4g.micro ARM │
  │  hbbs + hbbr  │   (rustdesk-server-pro, host networking)
  └───────────────┘
      ▲
      └── admin via SSM Session Manager (no SSH)
```

## Layout

```
terraform/
  providers.tf          # aws provider + s3 backend (partial config)
  variables.tf          # all inputs, no account-specific defaults
  main.tf               # module wiring
  outputs.tf            # relay IP / instance id
  terraform.tfvars.example
  backend.hcl.example
  modules/
    network/            # vpc, subnet, igw, route table
    rustdesk-server/    # ami, sg, iam, instance, eip, cloud-init
scripts/
  bootstrap-backend.sh  # one-time: S3 bucket + DynamoDB lock table
```

## Prerequisites

- AWS credentials available to the AWS CLI (`aws login`)
- `terraform >= 1.5`
- A domain (or just the EIP) for the web console + clients

## One-time backend bootstrap

Create the state bucket + lock table:

```sh
scripts/bootstrap-backend.sh rustdesk-terraform-state-<account-id> us-east-1
```

Then copy `backend.hcl.example` → `backend.hcl` and fill in the bucket/table.

## Configure

```sh
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit: aws_region, environment, availability_zone
```

## Deploy

```sh
cd terraform
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Post-launch (Server Pro setup)

1. Get the IP: `terraform output relay_public_ip`
2. Create an A record `remote.artoriastechlab.com` → that IP (GoDaddy DNS)
3. Open the web console: `https://<ip>:21114` (default login `admin` / `test1234`)
4. **Set your license** in the console (from https://rustdesk.com/pricing.html)
5. Change the default password immediately
6. Set up HTTPS for the web console (see RustDesk docs)

## Security notes

- SSH is closed by default. To open it (e.g. to your tailnet only), set
  `admin_ssh_cidrs = ["100.64.0.0/10"]` in `terraform.tfvars`.
- The web console runs plain HTTP on 21114 until you configure HTTPS — do this
  before exposing it to clients in production.
- Recommend an AWS Budgets alert at ~$15/mo to catch egress surprises.

## Cost (approx)

~$7.75/mo fixed (`t4g.micro` + 20GB gp3) + data egress at ~$0.09/GB + the
RustDesk Server Pro license.

## Account

Deploys into the Artorias AWS account (`REPLACE_WITH_ACCOUNT_ID`), which hosts only
artorias resources. IIO and other subprojects live in separate accounts.
