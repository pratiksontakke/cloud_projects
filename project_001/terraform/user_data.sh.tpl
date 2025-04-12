#!/bin/bash -xe
# User data script for Foundational Web App EC2 instances
# The '-xe' flags mean: exit immediately if a command exits with a non-zero status (-e)
# and print commands and their arguments as they are executed (-x).

# --- Basic Setup ---
# Update packages and install necessary tools
# Using yum for Amazon Linux 2. Use apt for Ubuntu.
yum update -y
yum install -y aws-cli jq git # Install AWS CLI v2, jq (for parsing JSON), git

# (Optional) Install and configure CloudWatch Agent
# yum install -y amazon-cloudwatch-agent
# TODO: Configure CloudWatch Agent (e.g., copy config from S3/Parameter Store, start agent)

# --- Install Application Runtime ---
# Example for Node.js (adjust for Python/Java etc.)
# Install Node Version Manager (nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# Source nvm script to add it to the current shell session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# Install a specific Node.js LTS version
nvm install --lts

# --- Get Application Code ---
# Create a directory for the app
APP_DIR="/opt/app"
mkdir -p $APP_DIR
cd $APP_DIR
# Clone the application repository (URL passed in as variable)
git clone ${app_source_url} . # Clone into current directory ($APP_DIR)

# --- Get Database Credentials ---
# Use AWS CLI to fetch the secret value using the ARN passed in as a variable
# Requires EC2 instance role to have secretsmanager:GetSecretValue permission
SECRET_ARN="${db_secret_arn}"
AWS_REGION="${aws_region}" # Get region from template variable

SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region $AWS_REGION --query SecretString --output text)

# Parse the JSON secret using jq
DB_USER=$(echo $SECRET_JSON | jq -r .username)
DB_PASS=$(echo $SECRET_JSON | jq -r .password)
# Get DB host and port from template variables (outputs from RDS module)
DB_HOST="${db_host}"
DB_PORT="${db_port}"
DB_NAME_VAR="${db_name}" # Use a different name to avoid conflict with hostname command

# --- Configure Application Environment ---
# Create an environment file or export variables
# Many Node apps use a .env file or process.env
echo "DB_HOST=${DB_HOST}" > .env
echo "DB_PORT=${DB_PORT}" >> .env
echo "DB_USER=${DB_USER}" >> .env
echo "DB_PASS=${DB_PASS}" >> .env
echo "DB_NAME=${DB_NAME_VAR}" >> .env
echo "PORT=${app_port}" >> .env # Ensure app listens on the correct port

# --- Install Application Dependencies ---
# Example for Node.js
npm install

# --- Setup Application as a Service (using systemd) ---
# Create a systemd service file
# Example for Node.js (adjust 'ExecStart' for Python/Java)
cat <<EOF > /etc/systemd/system/webapp.service
[Unit]
Description=My Foundational Web Application
Requires=network-online.target
After=network-online.target

[Service]
User=ec2-user # Or appropriate user
Group=ec2-user # Or appropriate group
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
ExecStart=/home/ec2-user/.nvm/versions/node/$(nvm current)/bin/node app.js # Adjust path and entrypoint (e.g., server.js, main.py)
Restart=on-failure
StandardOutput=journal
StandardError=journal
SyslogIdentifier=webapp

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable webapp.service
systemctl start webapp.service

# --- End of User Data ---
echo "User data script completed successfully.




#!/bin/bash -xe
# ... (previous setup steps: yum update, aws cli, jq, git, nvm, etc.) ...

# --- Install and Configure CloudWatch Agent ---
yum install -y amazon-cloudwatch-agent

# Fetch the configuration from SSM Parameter Store
CW_AGENT_CONFIG_PARAM_NAME="/${var.project_name}/${var.environment}/cloudwatch-agent-config" # Passed via templatefile function
AWS_REGION="${aws_region}" # Passed via templatefile function
CONFIG_OUTPUT_PATH="/opt/aws/amazon-cloudwatch-agent/bin/config.json"

aws ssm get-parameter --name $CW_AGENT_CONFIG_PARAM_NAME --region $AWS_REGION --query Parameter.Value --output text > $CONFIG_OUTPUT_PATH

# Start the CloudWatch Agent using the fetched configuration
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:$CONFIG_OUTPUT_PATH -s

# --- Get Application Code ---
# ... (rest of the script: git clone, get secrets, configure app, install deps, start service) ...