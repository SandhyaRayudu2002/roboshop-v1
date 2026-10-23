#!/bin/bash

set -o pipefail

logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/03-rabbitmq.sh.log"

R="\e[31m"
G="\e[32m"
N="\e[0m"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo access"
    exit 1
fi

mkdir -p "$logs_folder" || exit 1

timestamp() {
    date "+%F %T"
}

validate() {
    if [ "$1" -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${2}..${R}FAILED${N}" | tee -a "$logs_file"
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${2}..${G}SUCCESS${N}" | tee -a "$logs_file"
    fi
}

echo "$(timestamp) [INFO] ==== Script started Execution =====" | tee -a "$logs_file"

# Check the repository file
if [ ! -f rabbitmq.repo ]; then
    echo "rabbitmq.repo not found in the current directory"
    exit 1
fi

cp rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo
validate $? "Adding RabbitMQ repo"

# Import official signing keys
rpm --import https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
validate $? "Importing RabbitMQ signing key"

rpm --import https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
validate $? "Importing Erlang signing key"

rpm --import https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
validate $? "Importing RabbitMQ server signing key"

# Refresh repository metadata
dnf clean metadata
dnf makecache
validate $? "Refreshing DNF metadata"

# Install required packages
dnf install logrotate -y
validate $? "Installing logrotate"

dnf install erlang rabbitmq-server -y
validate $? "Installing RabbitMQ server"

# Enable and start RabbitMQ
systemctl enable rabbitmq-server
validate $? "Enabling RabbitMQ server"

systemctl start rabbitmq-server
validate $? "Starting RabbitMQ server"

# Verify service
systemctl is-active --quiet rabbitmq-server
validate $? "Checking RabbitMQ service"

# Create Roboshop user only if it doesn't exist
if ! rabbitmqctl list_users | awk '{print $1}' | grep -qx "roboshop"; then
    rabbitmqctl add_user roboshop 'roboshop123'
    validate $? "Creating RabbitMQ user"
else
    echo "$(timestamp) [INFO] RabbitMQ user already exists; skipping" | tee -a "$logs_file"
fi

rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*"
validate $? "Setting RabbitMQ permissions"

echo "$(timestamp) [INFO] ==== Script completed successfully =====" | tee -a "$logs_file"
