#!/bin/bash
{
exec 2>&1
echo "[$(date)] Starting Phase 3 bootstrap..."

# Install packages
apt update -y
apt install nodejs unzip wget npm mysql-client jq -y

# FIX: Installer AWS CLI v2 (la version apt est trop ancienne et bugguée)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
export PATH=$PATH:/usr/local/bin

# Download and extract code
echo "[$(date)] Downloading code..."
cd /home/ubuntu
wget https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACCAP1-1-91571/1-lab-capstone-project-1/code.zip -P /home/ubuntu
unzip -o code.zip -x "resources/codebase_partner/node_modules/*"
cd /home/ubuntu/resources/codebase_partner

# Install Node dependencies
echo "[$(date)] Installing npm packages..."
npm install aws aws-sdk

# FIX: Utiliser list-secrets avec --filter (describe-secret ne supporte pas --name-prefix)
echo "[$(date)] Fetching RDS secret..."
SECRET_ARN=""
for i in {1..20}; do
  SECRET_ARN=$(aws secretsmanager list-secrets \
    --filter Key=name,Values=rds-app-secret \
    --region us-east-1 \
    --query 'SecretList[0].ARN' \
    --output text 2>/dev/null)
  if [[ -n "$SECRET_ARN" && "$SECRET_ARN" != "None" ]]; then
    echo "[$(date)] Secret found: $SECRET_ARN"
    break
  fi
  echo "[$(date)] Attempt $i: Secret not found yet, retrying in 15s..."
  sleep 15
done

if [[ -z "$SECRET_ARN" || "$SECRET_ARN" == "None" ]]; then
  echo "[$(date)] ERROR: Could not find secret after 20 attempts!"
  exit 1
fi

# Get secret value
echo "[$(date)] Retrieving secret value..."
RDS_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region us-east-1 \
  --query SecretString \
  --output text)

if [[ -z "$RDS_SECRET" ]]; then
  echo "[$(date)] ERROR: Failed to retrieve secret value!"
  exit 1
fi

echo "[$(date)] Parsing secret..."
RDS_HOST=$(echo "$RDS_SECRET" | jq -r '.host')
RDS_USER=$(echo "$RDS_SECRET" | jq -r '.user')
RDS_PASSWORD=$(echo "$RDS_SECRET" | jq -r '.password')
RDS_DB=$(echo "$RDS_SECRET" | jq -r '.db')

echo "[$(date)] RDS_HOST=$RDS_HOST RDS_USER=$RDS_USER RDS_DB=$RDS_DB"

# Attendre que MySQL soit accessible
echo "[$(date)] Waiting for MySQL to be accessible..."
for i in {1..20}; do
  if mysql -h "$RDS_HOST" -u "$RDS_USER" -p"$RDS_PASSWORD" -e "SELECT 1;" &>/dev/null; then
    echo "[$(date)] MySQL is accessible!"
    break
  fi
  echo "[$(date)] Attempt $i: MySQL not ready yet, retrying in 15s..."
  sleep 15
done

# Create nodeapp user
echo "[$(date)] Creating nodeapp user..."
mysql -h "$RDS_HOST" -u "$RDS_USER" -p"$RDS_PASSWORD" -e \
  "CREATE USER IF NOT EXISTS 'nodeapp'@'%' IDENTIFIED WITH mysql_native_password BY 'student12';" 2>&1 | head -5
mysql -h "$RDS_HOST" -u "$RDS_USER" -p"$RDS_PASSWORD" -e \
  "GRANT ALL PRIVILEGES ON *.* TO 'nodeapp'@'%'; FLUSH PRIVILEGES;" 2>&1 | head -5

# FIX: Passer les variables d'env directement au processus npm
# (les `export` bash ne sont pas hérités par les processus lancés en background après la fin du script)
echo "[$(date)] Starting npm application..."
APP_DB_HOST="$RDS_HOST" \
APP_DB_USER="nodeapp" \
APP_DB_PASSWORD="student12" \
APP_DB_NAME="$RDS_DB" \
APP_PORT=80 \
npm start 2>&1 | tee /tmp/npm.log &

echo "[$(date)] Bootstrap complete at $(date)"
} | tee /tmp/bootstrap.log
