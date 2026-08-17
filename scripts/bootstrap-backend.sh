#!/usr/bin/env bash
set -euo pipefail
# One-time bootstrap: create the S3 state bucket + DynamoDB lock table.
# Usage: scripts/bootstrap-backend.sh <bucket-name> <region> [lock-table]

BUCKET="${1:?usage: $0 <bucket-name> <region> [lock-table]}"
REGION="${2:-us-east-1}"
TABLE="${3:-terraform-lock}"

aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration "LocationConstraint=$REGION"

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

aws dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo "backend ready: s3://$BUCKET (key=rustdesk/terraform.tfstate) + dynamodb:$TABLE"
