#!/bin/bash

USER_ID=$(id -u)
LOGS_FOLDER="/var/log/roboshop"
LOGS_FILE="${LOGS_FOLDER}/$(basename "$0").log"
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

# Create roboshop user if it does not exist
if id roboshop &>> "$LOGS_FILE"; then
    echo -e "$(timestamp) [INFO] User roboshop already exists...${Y}SKIPPING${N}" | tee -a "$LOGS_FILE"
else
    useradd --system --home /app --shell /sbin/nologin \
        --comment "roboshop system user" roboshop &>> "$LOGS_FILE"
    validate "$?" "Creating system user"
fi

# Download catalogue application
curl -fL -o /tmp/catalogue.zip \
    "https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/catalogue-v4.zip" \
    &>> "$LOGS_FILE"
validate "$?" "Downloading catalogue"

# Replace old application
rm -rf /app
validate "$?" "Removing old code"

mkdir -p /app
validate "$?" "Creating application directory"

unzip -oq /tmp/catalogue.zip -d /app &>> "$LOGS_FILE"
validate "$?" "Unzipping catalogue"

cd /app || exit 1

npm install &>> "$LOGS_FILE"
validate "$?" "Installing dependencies"

# Configure Catalogue service
if [ ! -f "$SCRIPTS_DIR/catalogue.service" ]; then
    echo "$(timestamp) [ERROR] catalogue.service not found" | tee -a "$LOGS_FILE"
    exit 1
fi

sed "s/DOMAIN_NAME/$DOMAIN_NAME/g" "$SCRIPTS_DIR/catalogue.service" \
    > /tmp/catalogue.service
validate "$?" "Configuring Catalogue service"

cp /tmp/catalogue.service /etc/systemd/system/catalogue.service
validate "$?" "Copying Catalogue service"

systemctl daemon-reload &>> "$LOGS_FILE"
validate "$?" "Reloading systemd"

systemctl enable catalogue &>> "$LOGS_FILE"
validate "$?" "Enabling Catalogue service"

systemctl start catalogue &>> "$LOGS_FILE"
validate "$?" "Starting Catalogue service"

# Configure MongoDB client
if [ ! -f "$SCRIPTS_DIR/mongo.repo" ]; then
    echo "$(timestamp) [ERROR] mongo.repo not found" | tee -a "$LOGS_FILE"
    exit 1
fi

cp "$SCRIPTS_DIR/mongo.repo" /etc/yum.repos.d/mongo.repo
validate "$?" "Adding MongoDB repository"

dnf install mongodb-mongosh -y &>> "$LOGS_FILE"
validate "$?" "Installing MongoDB client"

# Check existing products
PRODUCT_COUNT=$(mongosh --host "mongodb.$DOMAIN_NAME" --quiet \
    --eval 'db.getSiblingDB("catalogue").products.countDocuments()' \
    2>> "$LOGS_FILE")
validate "$?" "Connecting to MongoDB"

if [[ ! "$PRODUCT_COUNT" =~ ^[0-9]+$ ]]; then
    echo "$(timestamp) [ERROR] Invalid product count: $PRODUCT_COUNT" | tee -a "$LOGS_FILE"
    exit 1
fi

if [ "$PRODUCT_COUNT" -eq 0 ]; then
    if [ ! -f /app/db/master-data.js ]; then
        echo "$(timestamp) [ERROR] /app/db/master-data.js not found" | tee -a "$LOGS_FILE"
        exit 1
    fi

    mongosh --host "mongodb.$DOMAIN_NAME" \
        /app/db/master-data.js &>> "$LOGS_FILE"
    validate "$?" "Loading products"
else
    echo -e "$(timestamp) [INFO] Products are already loaded...${Y}SKIPPING${N}" | tee -a "$LOGS_FILE"
fi

# Restart Catalogue service
systemctl restart catalogue &>> "$LOGS_FILE"
validate "$?" "Restarting Catalogue"

systemctl is-active --quiet catalogue
validate "$?" "Checking Catalogue service status"

echo "$(timestamp) [INFO] Script completed in ${SECONDS} seconds" | tee -a "$LOGS_FILE"
echo "$(timestamp) [INFO] ==== Script completed execution ====" | tee -a "$LOGS_FILE"
