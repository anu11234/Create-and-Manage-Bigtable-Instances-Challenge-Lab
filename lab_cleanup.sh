#!/usr/bin/env bash
INSTANCE_ID="ecommerce-recommendations"
CLUSTER_1="ecommerce-recommendations-c1"

cbt deletetable SessionHistory || true
cbt deletetable PersonalizedProducts || true
cbt deletetable PersonalizedProducts_7_restored || true

gcloud bigtable backups delete PersonalizedProducts_7 --instance=$INSTANCE_ID --cluster=$CLUSTER_1 --quiet || true
gcloud bigtable instances delete $INSTANCE_ID --quiet

echo "=== Cleanup completed! Click 'Check my progress' on Task 5. ==="
