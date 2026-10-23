#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="sandhya.com"
hosted_zone_id="Z08101563NNCX0VHGCCRX"

for instance in "$@"
do
    echo "Creating instance: $instance"

    instance_id=$(aws ec2 run-instances \
        --image-id "$ami_id" \
        --instance-type "$instance_type" \
        --security-group-ids "$(aws ec2 describe-security-groups --group-names "roboshop-common" "roboshop-$instance" --query 'SecurityGroups[].GroupId' --output text | tr '\t' ',')" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    echo "$instance ID: $instance_id"

    if [ "$instance" != "frontend" ]; then
        ip=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].PrivateIpAddress' \
            --output text)
    else
        ip=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
    fi

    r53_record_name="${instance}.${domain_name}"
    echo "IP address: $ip"
    echo "DNS record: ${r53_record_name}"

    aws route53 change-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --change-batch "{
            \"Comment\": \"Updating A record\",
            \"Changes\": [
                {
                    \"Action\": \"UPSERT\",
                    \"ResourceRecordSet\": {
                        \"Name\": \"${r53_record_name}\",
                        \"Type\": \"A\",
                        \"TTL\": 1,
                        \"ResourceRecords\": [
                            {
                                \"Value\": \"$ip\"
                            }
                        ]
                    }
                }
            ]
        }"

done
