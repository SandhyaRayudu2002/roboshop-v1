#!/bin/bash

ami_id = "ami-0055977a6e828a4f4"
instance_type = "t3.micro"
domain_name = "sandhya.com"
hosted_zone_id = "Z08101563NNCX0VHGCCRX"


for instance in $@
do
    echo "creating instance: $instance"

    instance_id = $(aws ec2 run-instances \
    --image-id $ami_id \
    --instance-type $instance_type \
    --security-groups "roboshop-common" "roboshop-$instance" \
    --tag-specifications "ResourceType = instance,Tags = [{Key = Name,Value = roboshop-$instance}]" \
    --query 'Instances[0].InstanceId' \
    --output text
    )
    echo "$instance ID: $instance_id"

    if
    [$instance ! = "frontend"] ; then
        ip = $(aws ec2 describe-instance
        --instance_ids $instance_id
        --query 'reservations[].instance[].privateIpAddress'
        --output text
        )
        r53_record = "$instance.domain_name"
        else
        ip = $(aws ec2 describe-instance
        --instance_ids $instance_id
        --query 'reservations[].instance[].publicIpAddress'
        --output text
        )
        r53_record = "$instance.domain_name"
        # update  r53 record
        aws route53 change-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --change-batch '{
        "Comment": "Updating A record",
        "Changes": [
        {
        "Action": "UPSERT",
        "ResourceRecordSet": {
        "Name": "$r53_record_name",
        "Type": "A",
        "TTL": 1,
        "ResourceRecords": [
        {
        "Value": "192.0.2.42"
        }
        ]
        }
        }
        ]
        }'


    done