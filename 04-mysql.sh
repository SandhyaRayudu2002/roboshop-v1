
#!/bin/bash

set -o pipefail

USER_ID=$(id -u)
LOGS_FOLDER="/var/log/roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOGS_FILE="${LOGS_FOLDER}/${SCRIPT_NAME}.log"

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
    if [ "$1" -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] $2 ... ${R}FAILED${N}" | tee -a "$LOGS_FILE"
        exit 1
    else
        echo -e "$(timestamp) [INFO] $2 ... ${G}SUCCESS${N}" | tee -a "$LOGS_FILE"
    fi
}

echo "$(timestamp) [INFO] ==== Script started Execution ====" | tee -a "$LOGS_FILE"

dnf module enable mysql:8.4 -y &>> "$LOGS_FILE"
validate $? "Enabling MySQL 8.4 module"

dnf install mysql-server -y &>> "$LOGS_FILE"
validate $? "Installing MySQL server"

systemctl enable mysqld &>> "$LOGS_FILE"
validate $? "Enabling MySQL service"


 