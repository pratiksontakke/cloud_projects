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

# # --- Install and Configure CloudWatch Agent ---
# echo "Installing and configuring CloudWatch Agent..."
# yum install -y amazon-cloudwatch-agent

# CONFIG_OUTPUT_PATH="/opt/aws/amazon-cloudwatch-agent/bin/config.json"
# echo "Fetching CloudWatch Agent config from SSM parameter: ${cw_agent_config_param_name} in region ${aws_region}"
# aws ssm get-parameter --name "${cw_agent_config_param_name}" --region "${aws_region}" --query Parameter.Value --output text > "$CONFIG_OUTPUT_PATH"
# if [ $? -ne 0 ]; then
#   echo "WARNING: Failed to fetch CloudWatch Agent configuration from SSM. Agent will not collect custom logs/metrics."
# else
#   echo "Successfully fetched CloudWatch Agent configuration."
#   echo "Starting CloudWatch Agent..."
#   /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c "file:$CONFIG_OUTPUT_PATH" -s
#   if [ $? -ne 0 ]; then
#     echo "WARNING: Failed to start CloudWatch Agent."
#   else
#     echo "CloudWatch Agent started successfully."
#   fi
# fi

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
ln -s $NVM_DIR/versions/node/$NODE_VERSION/bin/npx /usr/bin/npx # Add npx symlink too

# --- Install PM2 Globally ---
echo "Installing PM2 globally..."
npm install pm2 -g
# Ensure PM2 command path is linked if needed (npm global link often handles this)
ln -s $NVM_DIR/versions/node/$NODE_VERSION/bin/pm2 /usr/bin/pm2
echo "PM2 installed."

# --- Get Application Code ---
APP_CLONE_DIR="/opt/app_repo" # Clone repo root here
# CORRECTED: Point to the specific app directory within the cloned repo
APP_DIR="/opt/app_repo/project_001"
echo "Creating application clone directory: $APP_CLONE_DIR"
mkdir -p $APP_CLONE_DIR
chown ec2-user:ec2-user $APP_CLONE_DIR
cd $APP_CLONE_DIR

echo "Cloning application code from https://github.com/pratiksontakke/cloud_projects.git"
# Run git clone as ec2-user
sudo -u ec2-user git clone https://github.com/pratiksontakke/cloud_projects.git .
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
# echo "Fetching database credentials from Secrets Manager: ${db_secret_arn}"
# SECRET_ARN="${db_secret_arn}"

# SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --region "${aws_region}" --query SecretString --output text)
# if [ $? -ne 0 ]; then
#   echo "FATAL: Failed to fetch database secret from Secrets Manager. Check IAM permissions and secret ARN. Exiting."
#   exit 1
# fi

# # Parse the JSON secret using jq
# DB_USER=$(echo "$SECRET_JSON" | jq -r .username)
# DB_PASS=$(echo "$SECRET_JSON" | jq -r .password)
# echo "Successfully parsed database credentials."

# --- Configure Application Environment ---
echo "Creating .env file in $APP_DIR"
# Use the values passed directly from Terraform templatefile
cat <<EOF > $APP_DIR/.env
# Database Configuration
DB_HOST=project01.c1y0c2wc2ggw.ap-south-1.rds.amazonaws.com
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=project01
DB_SSL_REQUIRE=true

# Application Port
PORT=8080

# Node Environment
NODE_ENV=production
EOF

chown ec2-user:ec2-user $APP_DIR/.env # Set ownership for the .env file
echo ".env file created."

# --- Install Application Dependencies ---
# (Keep this section as is - ensure no --production flag if dotenv needed)
echo "Installing application dependencies in $APP_DIR..."
cd $APP_DIR
sudo -u ec2-user bash -c "source $NVM_DIR/nvm.sh && npm install"
if [ $? -ne 0 ]; then
  echo "FATAL: npm install failed. Exiting."
  exit 1
fi
echo "Application dependencies installed."

# # --- Setup Application as a Service (using systemd) ---
# echo "Setting up systemd service for the web application..."
# #NODE_EXEC_PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin/node" # Get correct Node path

# cat <<EOF > /etc/systemd/system/webapp.service
# [Unit]
# Description=NodeJS Web Application (${project_name} - ${environment})
# Requires=network-online.target
# After=network-online.target amazon-cloudwatch-agent.service # Start after CW Agent

# [Service]
# User=ec2-user # Run as this user
# Group=ec2-user # Run as this group
# WorkingDirectory=${APP_DIR} # Set working directory to the app folder
# EnvironmentFile=${APP_DIR}/.env # Load environment variables from .env file
# ExecStart=/usr/bin/node server.js # Execute the main server file
# Restart=on-failure
# StandardOutput=journal # Log stdout to journald
# StandardError=journal  # Log stderr to journald
# SyslogIdentifier=webapp-${environment} # Tag logs with environment

# [Install]
# WantedBy=multi-user.target
# EOF

# # Reload systemd, enable and start the service
# echo "Reloading systemd, enabling and starting webapp service..."
# systemctl daemon-reload
# systemctl enable webapp.service
# systemctl start webapp.service
# if [ $? -ne 0 ]; then
#   echo "ERROR: Failed to start webapp service. Check status with 'systemctl status webapp.service' and logs with 'journalctl -u webapp.service'."
#   # Consider exiting if the app failing to start is critical
# else
#   echo "webapp service started successfully."
# fi



# --- Start Application with PM2 ---
echo "Starting application using PM2..."
cd $APP_DIR # Ensure we are in the correct directory
# Start the app using PM2, run as ec2-user
# Use an explicit name for the process
# Pass environment variables directly OR rely on .env loaded by dotenv (if setup in server.js)
sudo -u ec2-user bash -c "source $NVM_DIR/nvm.sh && pm2 start server.js --name webapp-${environment}"
if [ $? -ne 0 ]; then
  echo "ERROR: pm2 start command failed."
  # Don't exit here, try to setup startup script anyway
else
  echo "Application started via PM2."
fi

# --- Configure PM2 Startup Script ---
# This generates a systemd service FOR PM2 itself
echo "Configuring PM2 to start on boot..."
# The output of 'pm2 startup' typically provides a command that needs to be run as root
# We attempt to execute it directly. This might require sudo/root privileges.
env PATH=$PATH:/usr/bin:$NVM_DIR/versions/node/$NODE_VERSION/bin pm2 startup systemd -u ec2-user --hp /home/ec2-user
# Check if the previous command generated output/instructions - typically it asks to run a `sudo env ...` command.
# For non-interactive setup, we hope the command above does the job. If not, manual setup might be needed post-launch.

# Save the current PM2 process list so it restarts on boot
echo "Saving current PM2 process list..."
sudo -u ec2-user bash -c "source $NVM_DIR/nvm.sh && pm2 save"
echo "PM2 process list saved."


# --- End of User Data ---
echo "User Data Script Execution Completed."