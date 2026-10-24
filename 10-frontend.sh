#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/roboshop"
script_name=$(basename "$0")
logs_file="${logs_folder}/${script_name}.log"
domain_name="daws92s.store"
scripts_dir=$(dirname "$(realpath "$0")")

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ "$user_id" -ne 0 ]; then
    echo "Please run this script with sudo access."
    exit 1
fi

mkdir -p "$logs_folder" || exit 1

timestamp() {
    date "+%F %T"
}

validate() {
    local status=$1
    local message=$2

    if [ "$status" -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${message}..${R}FAILED${N}" | tee -a "$logs_file"
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${message}..${G}SUCCESS${N}" | tee -a "$logs_file"
    fi
}

echo "$(timestamp) [INFO] ==== Script started Execution =====" | tee -a "$logs_file"

# Install Nginx
dnf module disable nginx -y &>> "$logs_file"
dnf module enable nginx:1.26 -y &>> "$logs_file"
dnf install nginx -y &>> "$logs_file"
validate $? "Installing nginx"

# Enable and start Nginx
systemctl enable nginx &>> "$logs_file"
validate $? "Enabling nginx"

systemctl start nginx &>> "$logs_file"
validate $? "Starting nginx"

# Remove default Nginx content
rm -rf /usr/share/nginx/html/* &>> "$logs_file"
validate $? "Removing default nginx content"

# Download frontend code
curl -fL -o /tmp/frontend.zip \
    https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/frontend-v4.zip \
    &>> "$logs_file"
validate $? "Downloading frontend code"

# Extract frontend code
unzip -o /tmp/frontend.zip -d /usr/share/nginx/html &>> "$logs_file"
validate $? "Unzipping frontend code"

# Check configuration file
config_file="${scripts_dir}/roboshop.conf"

if [ ! -f "$config_file" ]; then
    echo "$(timestamp) [ERROR] Configuration file not found: $config_file" | tee -a "$logs_file"
    exit 1
fi

# Update domain name
sed -i "s/DOMAIN_NAME/${domain_name}/g" "$config_file"
validate $? "Updating roboshop domain"

# Ensure Nginx configuration directory exists
mkdir -p /etc/nginx/default.d &>> "$logs_file"
validate $? "Creating nginx configuration directory"

# Copy RoboShop configuration
cp "$config_file" /etc/nginx/default.d/roboshop.conf
validate $? "Copied roboshop config"

# Test Nginx configuration
nginx -t &>> "$logs_file"
validate $? "Nginx Configuration"

# Restart Nginx
systemctl restart nginx &>> "$logs_file"
validate $? "Restarting nginx"

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds" | tee -a "$logs_file"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a "$logs_file"
