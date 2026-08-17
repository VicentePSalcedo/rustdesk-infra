#!/usr/bin/env bash
set -euo pipefail
# One-time bootstrap: create the S3 state bucket (versioned, encrypted, private).
# State locking is S3-native (use_lockfile = true), so NO DynamoDB table is needed.
# Usage: scripts/bootstrap-backend.sh <bucket-name> <region>

BUCKET="${1:?usage: $0 <bucket-name> <region>}"
REGION="${2:-us-east-1}"

if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
else
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=$REGION"
fi

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
  '{"BlockPublicAcls":true,"IgnorePublicAcls":true,"BlockPublicPolicy":true,"RestrictPublicBuckets":true}'

echo "backend ready: s3://$BUCKET (state + S3-native .tflock locking, no DynamoDB)"
