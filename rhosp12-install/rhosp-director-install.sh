#!/bin/bash

# Log all output to rhosp-install.log
#exec &> rhosp-install.log

# Exit script on any command that returns an error state
set -e

# Check to ensure the user is running the script as "stack"
if [[ "$(id -nu)" != "stack" ]]; then
   echo "This script must be run as user stack"
   exit 1
fi

openstack undercloud install

source ~/stackrc
sudo yum -y install rhosp-director-images rhosp-director-images-ipa
cd ~/images
for i in /usr/share/rhosp-director-images/overcloud-full-latest-13.0.tar /usr/share/rhosp-director-images/ironic-python-agent-latest-13.0.tar; do tar -xvf $i; done
openstack overcloud image upload --image-path /home/stack/images/

# Check image upload (Optional)
openstack image list
ls -l /httpboot

## Find UUID of subnet to add nameservers to subnet
source ~/stackrc;

ADMIN_PASSWORD=$(sudo hiera admin_password)
printf "The admin password is %s\n" $ADMIN_PASSWORD
