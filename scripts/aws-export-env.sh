#!/usr/bin/env bash
# Export AWS `login` credentials as env vars so tools that don't understand the
# new `login` credential type (e.g. Terraform) can use them.
# Usage: eval "$(scripts/aws-export-env.sh)"
set -euo pipefail

aws configure export-credentials --profile "${1:-default}" --format env 2>/dev/null
