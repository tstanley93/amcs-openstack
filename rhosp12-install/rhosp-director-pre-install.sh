#!/bin/bash

# Log all output to rhosp-pre-install.log
#exec &> rhosp-pre-install.log

# Exit script on any command that returns an error state
set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Print hostname and add to /etc/hosts
short_name=$(echo `hostname` | cut -d. -f1)
long_name=`hostname -f`

cat <<EOF > /etc/hosts
127.0.0.1   ${long_name} ${short_name} localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF

subscription-manager register --username tstanley71 --password FruitL00p!
subscription-manager attach --pool=8a85f998653df0e8016547f2ebd367b0
subscription-manager repos --disable=*
subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-rh-common-rpms --enable=rhel-ha-for-rhel-7-server-rpms --enable=rhel-7-server-openstack-13-rpms
yum -y update
yum install -y python-tripleoclient bind-utils pciutils tcpdump facter tmux git

if ! id stack; then
	useradd stack
fi

echo -e 'SquidJ1g' | passwd --stdin stack
echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
chmod 0440 /etc/sudoers.d/stack
mkdir -p /home/stack/images && chown stack:stack /home/stack/images

sudo su stack
cd /home/stack
mkdir /home/stack/.git
touch /home/stack/.git/config
git config --global credential.helper store
git config --global http.sslverify false
git config --global user.email "tstanley@allmobilecs.com"
git config --global user.name "Thomas Stanley"
git clone https://github.com/tstanley93/amcs-openstack.git
ln -s /home/stack/amcs-openstack/rhosp12-install /home/stack/templates
ln -s /home/stack/amcs-openstack/rhosp12-install/undercloud.conf /home/stack/undercloud.conf

reboot
