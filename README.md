# rustdesk-infra

Self-hosted RustDesk **Server Pro** (hbbs + hbbr) on AWS, managed as Terraform.

**Design goals:** minimal footprint, secure by default, zero-touch provisioning.

## Architecture

- **One `t4g.micro` (ARM) instance** running hbbs + hbbr (Server Pro image)
- **Dedicated VPC** (`10.20.0.0/24`), single public subnet, **no NAT gateway**
- **No SSH** — admin access via AWS SSM Session Manager (IAM, no keys, no port 22)
- **Security group** exposes `21114`–`21119` TCP + `21116` UDP
- **Web console** on `21114` for license, users, devices, access control
- **Caddy** reverse proxy terminates HTTPS (auto Let's Encrypt) in front of `:21114`
- **Elastic IP** for a stable public address; **IMDSv2** enforced; encrypted gp3 EBS
- **Separate data volume** (`/var/lib/rustdesk`) with nightly DLM snapshots — see
  [Data protection](#data-protection)

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
  bootstrap-backend.sh  # one-time: S3 bucket (versioned/encrypted/private)
```

## Prerequisites

- AWS credentials available to the AWS CLI (`aws login`)
- `terraform >= 1.10` (S3-native `use_lockfile` state locking)
- A domain (or just the EIP) for the web console + clients

## One-time backend bootstrap

Create the state bucket (versioned, encrypted, private):

```sh
scripts/bootstrap-backend.sh rustdesk-terraform-state-<account-id> us-east-1
```

Then copy `backend.hcl.example` → `backend.hcl` and fill in the bucket name.

**State locking is S3-native** (`use_lockfile = true`): Terraform writes a `.tflock`
object into the bucket next to the state file during `plan`/`apply` and removes it
when done. **No DynamoDB table, no local lock file** — nothing lives in the repo or
on your workstation.

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
3. Open the web console: `https://remote.artoriastechlab.com` (default login
   `admin` / `test1234`). HTTPS is handled automatically by Caddy (Let's Encrypt)
   in front of `:21114` — no manual step.
4. **Set your license** in the console (from https://rustdesk.com/pricing.html)
5. Change the default password immediately

## Data protection

The server's durable state (license binding, `id_ed25519`, client database) is kept
on a **separate EBS data volume**, not the root disk, so it survives instance
replacement and accidental root-disk loss.

- **Volume** — 20 GiB encrypted gp3, attached at `/dev/sdf`, mounted at
  `/var/lib/rustdesk` via `nofail` fstab entry (cloud-init formats/mounts on first
  boot).
- **Snapshots** — AWS DLM takes a nightly snapshot at 03:00 UTC, 7-day rolling
  retention. Targets the volume by the `RustdeskData = "true"` tag.
- **Root disk is disposable** — everything on it is reconstructible from this repo
  + cloud-init, so it is intentionally not backed up.
- **Restore** — restore the latest snapshot to a new volume, attach to a fresh
  instance; cloud-init mounts it automatically (same fstab logic). No manual steps.

Snapshots are crash-consistent, which is safe for RustDesk's SQLite database —
SQLite replays the WAL journal on next open, so a snapshot taken mid-write restores
cleanly. No DB pause needed at this scale.

## Security notes

- SSH is closed by default. To open it (e.g. to your tailnet only), set
  `admin_ssh_cidrs = ["100.64.0.0/10"]` in `terraform.tfvars`.
- The web console is served over HTTPS via Caddy (auto Let's Encrypt, auto-renew);
  the `:21114` port is still reachable directly, so keep it firewalled to trusted
  CIDRs if you want to enforce HTTPS-only.
- Recommend an AWS Budgets alert at ~$15/mo to catch egress surprises.

## Cost (approx)

~$7.75/mo fixed (`t4g.micro` + 20GB gp3) + data egress at ~$0.09/GB + the
RustDesk Server Pro license.

## Account

Deploys into the Artorias AWS account (`REPLACE_WITH_ACCOUNT_ID`), which hosts only
artorias resources. IIO and other subprojects live in separate accounts.
