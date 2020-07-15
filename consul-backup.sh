#!/bin/sh

# Requirements
#
# curl
# openssl
# jq
# mktemp
# consul

######################
# CONFIGURATION
######################
# BUCKET - S3 bucket to upload to
# PREFIX - Key prefix within S3 to upload to
# VAULT_ADDR - Vault server address
# VAULT_TOKEN - Vault access token
# VAULT_STS_ROLE - AWS STS role name in vault

echo "Backing up consul database"

echo "Finding consul API service..."
CONSUL_IP=$(ip route show | awk '/default/ {print $3}')
CONSUL_HTTP_ADDR="http://$CONSUL_IP:8500"
export CONSUL_HTTP_ADDR

TMPDIR=`mktemp -d`
FILE_NAME=`date -u -Iminutes`
FILE_PATH=$TMPDIR/$FILE_NAME
consul snapshot save $FILE_PATH
echo "Snapshot exported: $FILE_PATH"

echo "Getting credentials lease from vault..."
LEASE_DATA=$(curl -s -k -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/aws/sts/$VAULT_STS_ROLE?ttl=900")
LEASE_ID=$(echo $LEASE_DATA | jq -r .lease_id)
AWS_ACCESS_KEY_ID=$(echo $LEASE_DATA | jq -r .data.access_key)
AWS_SECRET_ACCESS_KEY=$(echo $LEASE_DATA | jq -r .data.secret_key)
AWS_SECURITY_TOKEN=$(echo $LEASE_DATA | jq -r .data.security_token)
echo "Lease ID: $LEASE_ID"

DATE=$(date -R)
COMMAND="PUT\n\napplication/octet-stream\n$DATE\nx-amz-security-token:$AWS_SECURITY_TOKEN\n/$BUCKET/$PREFIX/$FILE_NAME"
ENCODED=$(echo -en $COMMAND | openssl sha1 -hmac $AWS_SECRET_ACCESS_KEY -binary | base64)

echo "Uploading to S3..."
curl -f -s -X PUT -T "$FILE_PATH" -H "Host: $BUCKET.s3.amazonaws.com" -H "Date: $DATE" -H "Content-Type: application/octet-stream" -H "Authorization: AWS $AWS_ACCESS_KEY_ID:$ENCODED" -H "X-AMZ-Security-Token: $AWS_SECURITY_TOKEN" https://$BUCKET.s3.amazonaws.com/$PREFIX/$FILE_NAME
BACKUP_RESULT=$?
echo "Upload complete"

echo "Cleaning up..."
rm -rf $TMPDIR
echo "DONE"

if [ $BACKUP_RESULT -ne 0 ]
then
    echo "CONSUL BACKUP FAILED"
else
    echo "CONSUL BACKUP SUCCESS"
fi
