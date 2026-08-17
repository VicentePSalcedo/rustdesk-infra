# rustdesk-infra

Self-hosted RustDesk relay (hbbs + hbbr) on AWS, managed as Terraform.

**Design goals:** minimal footprint, secure by default, zero-touch provisioning.

## Architecture

- **One `t4g.micro` (ARM) instance** running hbbs + hbbr in Docker
- **Dedicated VPC** (`10.20.0.0/24`), single public subnet, **no NAT gateway**
- **No SSH** — admin access via AWS SSM Session Manager (IAM, no keys, no port 22)
- **Security group** exposes only `21115/tcp`, `21116/tcp+udp`, `21117/tcp`
- **Shared key** (from SSM Parameter Store) so only your clients can register
- **Elastic IP** for a stable public address; **IMDSv2** enforced; encrypted gp3 EBS

```
public internet
      │
      ▼  EIP (rd.example.com)
  ┌───────────────┐  SG: 21115/tcp, 21116/tcp+udp, 21117/tcp
  │ t4g.micro ARM │
  │  hbbs + hbbr  │
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
  outputs.tf            # relay IP / key param / instance id
  terraform.tfvars.example
  backend.hcl.example
  modules/
    network/            # vpc, subnet, igw, route table
    rustdesk-server/    # ami, sg, iam, instance, eip, cloud-init
scripts/
  bootstrap-backend.sh  # one-time: S3 bucket + DynamoDB lock table
```

## Prerequisites

- AWS credentials available to the AWS CLI (SSO / access keys / role)
- `terraform >= 1.5`
- A domain (or just the EIP) to point clients at

## One-time backend bootstrap

Create the state bucket + lock table:

```sh
scripts/bootstrap-backend.sh rustdesk-terraform-state-<account-id> us-east-1
```

Then copy `backend.hcl.example` → `backend.hcl` and fill in the bucket/table.

## Configure

```sh
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit: aws_region, environment, availability_zone,
#       rustdesk_key (generate: openssl rand -hex 16),
#       relay_host (A record -> EIP, set after first apply)
```

## Deploy

```sh
cd terraform
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

After apply, create a DNS `A` record for `relay_host` pointing at the Elastic IP
(`terraform output relay_public_ip`). Clients then set:

- **ID server** = `relay_host`
- **Relay server** = `relay_host`
- **Key** = the shared key

## Security notes

- SSH is closed by default. To open it (e.g. to your tailnet only), set
  `admin_ssh_cidrs = ["100.64.0.0/10"]` in `terraform.tfvars`.
- The shared key is stored in SSM Parameter Store (SecureString) and fetched at
  boot via the instance role — it is never in plaintext `user_data`.
- Recommend an AWS Budgets alert at ~$15/mo to catch egress surprises.

## Cost (approx)

~$7.75/mo fixed (`t4g.micro` + 20GB gp3) + data egress at ~$0.09/GB.

## Open decisions

- AWS account placement (same account as IIO vs separate account under Organizations)
- Auth method for the AWS CLI (SSO vs access keys vs assume-role)
