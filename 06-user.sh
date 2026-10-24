#!/bin/bash

USER_ID=$(id -u)
LOGS_FOLDER="/var/log/roboshop"
LOGS_FILE="${LOGS_FOLDER}/04-user.sh.log"
DOMAIN_NAME="daws92s.store"
SCRIPTS_DIR=$(dirname "$(realpath "$0")")

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ "$USER_ID" -ne 0 ]; then
    echo "Please run this script with sudo access."
    exit 1
fi

mkdir -p "$LOGS_FOLDER" || exit 1

timestamp() {
    date "+%F %T"
}

validate() {
    local status="$1"
    local message="$2"

    if [ "$status" -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${message}...${R}FAILED${N}" | tee -a "$LOGS_FILE"
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${message}...${G}SUCCESS${N}" | tee -a "$LOGS_FILE"
    fi
}

echo "$(timestamp) [INFO] ==== Script started execution ====" | tee -a "$LOGS_FILE"

# Install Node.js 24
dnf module disable nodejs -y &>> "$LOGS_FILE"
validate "$?" "Disabling Node.js module"

dnf module enable nodejs:24 -y &>> "$LOGS_FILE"
validate "$?" "Enabling Node.js 24 module"

dnf install nodejs -y &>> "$LOGS_FILE"
validate "$?" "Installing Node.js 24"

# Create roboshop user if missing
if id roboshop &>> "$LOGS_FILE"; then
    echo "$(timestamp) [INFO] roboshop user already exists; skipping."
else
    useradd --system --home /app --shell /sbin/nologin \
        --comment "roboshop system user" roboshop &>> "$LOGS_FILE"
    validate "$?" "Creating roboshop user"
fi

# Download application
curl -fL -o /tmp/user.zip \
    "https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/user-v4.zip" \
    &>> "$LOGS_FILE"
validate "$?" "Downloading user application"

# Extract application
rm -rf /app
validate "$?" "Removing old application"

mkdir -p /app
validate "$?" "Creating application directory"

unzip -oq /tmp/user.zip -d /app &>> "$LOGS_FILE"
validate "$?" "Extracting user application"

cd /app || exit 1

npm install &>> "$LOGS_FILE"
validate "$?" "Installing dependencies"

# Check service definition before configuring it
if [ ! -f "$SCRIPTS_DIR/user.service" ]; then
    echo "$(timestamp) [ERROR] user.service not found in $SCRIPTS_DIR" | tee -a "$LOGS_FILE"
    echo "Place the correct user.service file beside this script and run it again."
    exit 1
fi

sed "s/DOMAIN_NAME/$DOMAIN_NAME/g" "$SCRIPTS_DIR/user.service" \
    > /tmp/user.service
validate "$?" "Configuring user service"

cp /tmp/user.service /etc/systemd/system/user.service
validate "$?" "Installing user service"

systemctl daemon-reload &>> "$LOGS_FILE"
validate "$?" "Reloading systemd"

systemctl enable user &>> "$LOGS_FILE"
validate "$?" "Enabling user service"

systemctl restart user &>> "$LOGS_FILE"
validate "$?" "Starting user service"

systemctl is-active --quiet user
validate "$?" "Checking user service status"

echo "$(timestamp) [INFO] Script completed in ${SECONDS} seconds" | tee -a "$LOGS_FILE"
echo "$(timestamp) [INFO] ==== Script completed execution ====" | tee -a "$LOGS_FILE"
