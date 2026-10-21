#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="sandhya.com"
hosted_zone_id="Z08101563NNCX0VHGCCRX"


for instance in $@
do
 echo "creating instance: $instance"
 
done