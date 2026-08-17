#!/usr/bin/env bash
set -euo pipefail
# Purge a versioned S3 bucket: delete every object version + delete marker, then the bucket.
# Usage: purge-bucket.sh <bucket-name>
BUCKET="${1:?usage: $0 <bucket-name>}"

echo "=== $BUCKET ==="

while :; do
  # Single JMESPath query merges Versions + DeleteMarkers into the delete-objects shape:
  #   { "Objects": [ {Key,VersionId}, ... ], "Quiet": true }
  aws s3api list-object-versions --bucket "$BUCKET" --output json \
    --query '{Objects: [Versions[].{Key:Key,VersionId:VersionId}, DeleteMarkers[].{Key:Key,VersionId:VersionId}][], Quiet: `true`}' \
    > /tmp/delete-manifest.json 2>/dev/null

  # Count objects in the manifest without jq
  n=$(grep -c '"VersionId"' /tmp/delete-manifest.json || true)
  echo "  versions/markers in this batch: $n"
  [ "$n" -eq 0 ] && break

  aws s3api delete-objects --bucket "$BUCKET" --delete file:///tmp/delete-manifest.json > /dev/null
done

echo "  deleting bucket..."
aws s3api delete-bucket --bucket "$BUCKET"
echo "  DONE — $BUCKET removed"
