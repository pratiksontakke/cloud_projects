#!/bin/bash -xe
# User data script for Node.js App (Project 001)

echo "Starting User Data Script Execution..."

# --- Parameters passed from Terraform ---
# app_source_url="${app_source_url}" # Example: https://github.com/pratiksontakke/cloud_projects.git
# db_secret_arn="${db_secret_arn}"
# aws_region="${aws_region}"
# db_host="${db_host}"
# db_port="${db_port}"
# db_name="${db_name}"
# app_port="${app_port}"
# cw_agent_config_param_name="${cw_agent_config_param_name}"
# project_name="${project_name}"
# environment="${environment}"

# --- Basic Setup ---
echo "Updating packages and installing tools..."
yum update -y
yum install -y aws-cli jq git

# --- Install and Configure CloudWatch Agent ---
echo "Installing and configuring CloudWatch Agent..."
yum install -y amazon-cloudwatch-agent

CONFIG_OUTPUT_PATH="/opt/aws/amazon-cloudwatch-agent/bin/config.json"
echo "Fetching CloudWatch Agent config from SSM parameter: ${cw_agent_config_param_name} in region ${aws_region}"
aws ssm get-parameter --name "${cw_agent_config_param_name}" --region "${aws_region}" --query Parameter.Value --output text > "$CONFIG_OUTPUT_PATH"
if [ $? -ne 0 ]; then
  echo "WARNING: Failed to fetch CloudWatch Agent configuration from SSM. Agent will not collect custom logs/metrics."
else
  echo "Successfully fetched CloudWatch Agent configuration."
  echo "Starting CloudWatch Agent..."
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c "file:$CONFIG_OUTPUT_PATH" -s
  if [ $? -ne 0 ]; then
    echo "WARNING: Failed to start CloudWatch Agent."
  else
    echo "CloudWatch Agent started successfully."
  fi
fi

# --- Install Node.js ---
echo "Setting up Node.js using nvm..."
# Run as ec2-user for nvm installation
sudo -u ec2-user bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
# Source nvm for the current script execution (optional, but good for clarity)
export NVM_DIR="/home/ec2-user/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# Install LTS Node.js using nvm command sourced previously
nvm install --lts
NODE_VERSION=$(nvm current)
echo "Node.js version $NODE_VERSION installed."
# Make node/npm globally available for root too if needed later (or use full paths)
ln -s $NVM_DIR/versions/node/$NODE_VERSION/bin/node /usr/bin/node
ln -s $NVM_DIR/versions/node/$NODE_VERSION/bin/npm /usr/bin/npm

# --- Get Application Code ---
APP_CLONE_DIR="/opt/app_repo" # Clone repo here
APP_DIR="/opt/app_repo/project_001" # Actual application directory
echo "Creating application directory structure: $APP_DIR"
mkdir -p $APP_CLONE_DIR
chown ec2-user:ec2-user $APP_CLONE_DIR
cd $APP_CLONE_DIR

echo "Cloning application code from ${app_source_url}"
# Run git clone as ec2-user
sudo -u ec2-user git clone "${app_source_url}" .
if [ $? -ne 0 ]; then
  echo "FATAL: Failed to clone application repository. Exiting."
  exit 1
fi
# Check if the app directory exists after clone
if [ ! -d "$APP_DIR" ]; then
  echo "FATAL: Application directory $APP_DIR not found after cloning. Check repository structure and path."
  exit 1
fi
echo "Application code cloned."

# --- Get Database Credentials ---
echo "Fetching database credentials from Secrets Manager: ${db_secret_arn}"
SECRET_ARN="${db_secret_arn}"

SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --region "${aws_region}" --query SecretString --output text)
if [ $? -ne 0 ]; then
  echo "FATAL: Failed to fetch database secret from Secrets Manager. Check IAM permissions and secret ARN. Exiting."
  exit 1
fi

# Parse the JSON secret using jq
DB_USER=$(echo "$SECRET_JSON" | jq -r .username)
DB_PASS=$(echo "$SECRET_JSON" | jq -r .password)
echo "Successfully parsed database credentials."

# --- Configure Application Environment ---
echo "Creating .env file in $APP_DIR"
# Use the values passed directly from Terraform templatefile
cat <<EOF > $APP_DIR/.env
# Database Configuration
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS} # Note: Use DB_PASS, not PASSWORD, to match the modified db.config.js example
DB_NAME=${db_name}
DB_SSL_REQUIRE=true # Explicitly set based on RDS defaults

# Application Port
PORT=${app_port}

# Node Environment (Optional but recommended)
NODE_ENV=production
EOF
chown ec2-user:ec2-user $APP_DIR/.env # Set ownership for the .env file
echo ".env file created."

# --- Install Application Dependencies ---
echo "Installing application dependencies in $APP_DIR..."
cd $APP_DIR # Navigate to the app directory containing package.json
# Run npm install as the ec2-user
sudo -u ec2-user bash -c "source $NVM_DIR/nvm.sh && npm install --production" # Use --production to skip devDependencies
if [ $? -ne 0 ]; then
  echo "FATAL: npm install failed. Exiting."
  exit 1
fi
echo "Application dependencies installed."

# --- Setup Application as a Service (using systemd) ---
echo "Setting up systemd service for the web application..."
NODE_EXEC_PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin/node" # Get correct Node path

cat <<EOF > /etc/systemd/system/webapp.service
[Unit]
Description=NodeJS Web Application (${project_name} - ${environment})
Requires=network-online.target
After=network-online.target amazon-cloudwatch-agent.service # Start after CW Agent

[Service]
User=ec2-user # Run as this user
Group=ec2-user # Run as this group
WorkingDirectory=${APP_DIR} # Set working directory to the app folder
EnvironmentFile=${APP_DIR}/.env # Load environment variables from .env file
ExecStart=${NODE_EXEC_PATH} server.js # Execute the main server file
Restart=on-failure
StandardOutput=journal # Log stdout to journald
StandardError=journal  # Log stderr to journald
SyslogIdentifier=webapp-${environment} # Tag logs with environment

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
echo "Reloading systemd, enabling and starting webapp service..."
systemctl daemon-reload
systemctl enable webapp.service
systemctl start webapp.service
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start webapp service. Check status with 'systemctl status webapp.service' and logs with 'journalctl -u webapp.service'."
  # Consider exiting if the app failing to start is critical
else
  echo "webapp service started successfully."
fi

# --- End of User Data ---
echo "User Data Script Execution Completed."