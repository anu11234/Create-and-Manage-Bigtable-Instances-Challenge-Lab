#!/usr/bin/env bash
set -e

# Dynamically retrieve Project ID and default variables
export PROJECT_ID=$(gcloud config get-value project)
export INSTANCE_ID="ecommerce-recommendations"
export CLUSTER_1="ecommerce-recommendations-c1"
export CLUSTER_2="ecommerce-recommendations-c2"
export REGION="us-east4"
export ZONE_1="us-east4-b"
export ZONE_2="us-east4-c"

echo "=== 1. Creating Bigtable Instance ==="
gcloud bigtable instances create $INSTANCE_ID \
    --display-name=$INSTANCE_ID \
    --cluster=$CLUSTER_1 \
    --cluster-zone=$ZONE_1 \
    --cluster-storage-type=SSD \
    --cluster-autoscaling-min-nodes=1 \
    --cluster-autoscaling-max-nodes=5 \
    --cluster-autoscaling-cpu-target=60

echo "=== 2. Creating Tables ==="
echo "project = $PROJECT_ID" > ~/.cbtrc
echo "instance = $INSTANCE_ID" >> ~/.cbtrc

cbt createtable SessionHistory families=Engagements,Sales
cbt createtable PersonalizedProducts families=Recommendations

echo "=== 3. Restarting Dataflow API & Running Jobs ==="
gcloud services disable dataflow.googleapis.com --force
gcloud services enable dataflow.googleapis.com

gcloud dataflow jobs run import-sessions \
    --gcs-location=gs://dataflow-templates/latest/SequenceFile_to_Bigtable \
    --region=$REGION \
    --parameters \
bigtableProject=$PROJECT_ID,\
bigtableInstanceId=$INSTANCE_ID,\
bigtableTableId=SessionHistory,\
inputFilePattern=gs://spls/gsp380/retail-engagements-sales-00000-of-00001

gcloud dataflow jobs run import-recommendations \
    --gcs-location=gs://dataflow-templates/latest/SequenceFile_to_Bigtable \
    --region=$REGION \
    --parameters \
bigtableProject=$PROJECT_ID,\
bigtableInstanceId=$INSTANCE_ID,\
bigtableTableId=PersonalizedProducts,\
inputFilePattern=gs://spls/gsp380/retail-recommendations-00000-of-00001

echo "=== 4. Adding Cluster Replication ==="
gcloud bigtable clusters create $CLUSTER_2 \
    --instance=$INSTANCE_ID \
    --zone=$ZONE_2 \
    --autoscaling-min-nodes=1 \
    --autoscaling-max-nodes=5 \
    --autoscaling-cpu-target=60

echo "=== 5. Creating Backup & Restoring Table ==="
gcloud bigtable backups create PersonalizedProducts_7 \
    --instance=$INSTANCE_ID \
    --cluster=$CLUSTER_1 \
    --table=PersonalizedProducts \
    --expiration-date=$(date -u -d "+7 days" +%Y-%m-%dT%H:%M:%SZ)

gcloud dataflow jobs list --region=$REGION --status=active

gcloud bigtable instances tables restore \
    --source-instance=$INSTANCE_ID \
    --source-cluster=$CLUSTER_1 \
    --source-backup=PersonalizedProducts_7 \
    --destination-instance=$INSTANCE_ID \
    --destination-table=PersonalizedProducts_7_restored

echo "=== Tasks 1–4 Completed! Verify your progress on the lab page before proceeding to deletion. ==="
