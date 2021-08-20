#!/bin/bash
set -e
start=$(date +%s)
#trap "set +x; sleep 1; set -x" DEBUG
#export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin/"
#IP_REGEX='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'

####-----Functions-------------------------------------------------------------

usage() { 
    printf "%b" "    Usage: $0
    Pre-Requisites:
    To run this script you will need to have installed the following packages;
        - bc [sudo apt-get install bc]
        - OpenStack python command line [see: https://docs.openstack.org/newton/user-guide/common/cli-install-openstack-command-line-clients.html]
    "$IRed"Note:\033[0m Please be careful of the parameter construction, it must match exactly to work...
    Example: /home/stack/rhosp-post-install.sh overcloudrcfile=/home/stack/thomas14rc imagedir=/home/stack/vm_images

    Parameters:
    "$IYellow"overcloudrcfile=\033[0m<the full path to the overlcoud rc file [/home/stack/overcloudrc]>
    "$IYellow"imagedir=\033[0m<the full path to the directory containing the images [/home/stack/images/]>
    "$IYellow"publickeyfile=\033[0m<the full path to your public key that will be used to ssh to your vm's [/home/somefile.pem]>
    "$IYellow"defaultSGID=\033[0m<the ID of the default security group of the project that you are using... >
    \n"
    exit 1
}

doLog() {
    # ------------------------------------------------------------------------------
    # MAKE SURE TO TAKE A LOG FILE AS A PARAMETER
    # echo pass params and print them to a log file and terminal
    # with timestamp and $host_name and $0 PID
    # usage:
    # doLog "INFO INFO some info message"
    # doLog "INFO DEBUG some debug message"
    # doLog "INFO WARN some warning message"
    # doLog "INFO ERROR some really ERROR message"
    # doLog "INFO FATAL some really fatal message"
    # ------------------------------------------------------------------------------
    log_file=""
    type_of_msg=$(echo $*|cut -d" " -f1)
    msg=$(echo "$*"|cut -d" " -f2-)
    [[ $type_of_msg == DEBUG ]] && [[ $do_print_debug_msgs -ne 1 ]] && return
    [[ $type_of_msg == INFO ]] && type_of_msg="INFO" # one space for aligning
    [[ $type_of_msg == WARN ]] && type_of_msg="WARN" # as well

    # print to the terminal if we have one
    if [[ $type_of_msg == "INFO" ]]; then
        test -t 1 && echo -e "${IYellow}[$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` ${msg}\033[0m"
    elif [[ $type_of_msg == "WARN" ]]; then
        test -t 1 && echo -e "${IRed}[$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` ${msg}\033[0m"
    else
        test -t 1 && echo -e "${IGreen}[$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` ${msg}\033[0m"
    fi
    # define default log file none specified in cnf file
    #test -z $log_file && mkdir -p $product_instance_dir/dat/log/bash && log_file="$product_instance_dir/dat/log/bash/$run_unit.`date "+%Y%m"`.log"
    echo " [$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` ""$msg" >> $log_file
}

noLog() {
    # ------------------------------------------------------------------------------
    # echo pass params and print them to a log file and terminal
    # with timestamp and $host_name and $0 PID
    # usage:
    # noLog "INFO INFO some info message"
    # noLog "INFO DEBUG some debug message"
    # noLog "INFO WARN some warning message"
    # noLog "INFO ERROR some really ERROR message"
    # noLog "INFO FATAL some really fatal message"
    # ------------------------------------------------------------------------------
    type_of_msg=$(echo $*|cut -d" " -f1)
    msg=$(echo "$*"|cut -d" " -f2-)
    [[ $type_of_msg == DEBUG ]] && [[ $do_print_debug_msgs -ne 1 ]] && return
    [[ $type_of_msg == INFO ]] && type_of_msg="INFO" # one space for aligning
    [[ $type_of_msg == WARN ]] && type_of_msg="WARN" # as well

    # print to the terminal if we have one
    if [[ $type_of_msg == "INFO" ]]; then
        test -t 1 && echo -e "${IYellow}[$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` ${msg}\033[0m"
    elif [[ $type_of_msg == "WARN" ]]; then
        test -t 1 && echo -e "${IRed}[$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` ${msg}\033[0m"
    else
        test -t 1 && echo -e "${IGreen}[$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` ${msg}\033[0m"
    fi
    # define default log file none specified in cnf file
    #test -z $log_file && mkdir -p $product_instance_dir/dat/log/bash && log_file="$product_instance_dir/dat/log/bash/$run_unit.`date "+%Y%m"`.log"
    #echo " [$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` ""$msg"
}

spinner() {
    ## How to use:
    ## sleep 10 &
    ## spinner "$!"
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

version_gt() { 
    # ------------------------------------------------------------------------------
    # first_version=5.100.2
    # second_version=5.1.2
    # if version_gt $first_version $second_version; then
    #     echo "$first_version is greater than $second_version !"
    # fi
    # ------------------------------------------------------------------------------
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; 
}

getJsonVal() {
   python -c "import sys, json; print json.load(sys.stdin)$1";   
}

preReqs() {
    result=$(( bc --version ) 2>&1)

    if [[ $result == *"The program"* ]]; then
        noLog "WARN bc is not installed..."
        echo "Do you want me to install it? [Y/n]"
        read yn
        if [[ $yn = Y || y ]]; then
            sudo apt install bc -yn
        else
            noLog "WARN Exiting Script"
            noLog "WARN The program bc must be installed to use this script."
            exit 101
        fi
    fi

    result=$(( openstack --version ) 2>&1)

    if [[ $result == *"The program"* ]]; then
        noLog "WARN Python OpenStack Client is not installed..."
        echo "Do you want me to install it? [Y/n]"
        read yn
        if [[ $yn = Y || y ]]; then
            sudo apt install python3-openstackclient -yn
        else
            noLog "WARN Exiting Script"
            noLog "WARN The program python openstack client must be installed to use this script."
            exit 101
        fi
    fi
}

colors() {
    # Text Colors:
    # Use echo -e "${RED}<text>"
    # Reset'\033[0m'       # Text Reset

    # Regular Colors
    Black='\033[0;30m'        # Black
    Red='\033[0;31m'          # Red
    Green='\033[0;32m'        # Green
    Yellow='\033[0;33m'       # Yellow
    Blue='\033[0;34m'         # Blue
    Purple='\033[0;35m'       # Purple
    Cyan='\033[0;36m'         # Cyan
    White='\033[0;37m'        # White

    # Bold
    BBlack='\033[1;30m'       # Black
    BRed='\033[1;31m'         # Red
    BGreen='\033[1;32m'       # Green
    BYellow='\033[1;33m'      # Yellow
    BBlue='\033[1;34m'        # Blue
    BPurple='\033[1;35m'      # Purple
    BCyan='\033[1;36m'        # Cyan
    BWhite='\033[1;37m'       # White

    # Underline
    UBlack='\033[4;30m'       # Black
    URed='\033[4;31m'         # Red
    UGreen='\033[4;32m'       # Green
    UYellow='\033[4;33m'      # Yellow
    UBlue='\033[4;34m'        # Blue
    UPurple='\033[4;35m'      # Purple
    UCyan='\033[4;36m'        # Cyan
    UWhite='\033[4;37m'       # White

    # Background
    On_Black='\033[40m'       # Black
    On_Red='\033[41m'         # Red
    On_Green='\033[42m'       # Green
    On_Yellow='\033[43m'      # Yellow
    On_Blue='\033[44m'        # Blue
    On_Purple='\033[45m'      # Purple
    On_Cyan='\033[46m'        # Cyan
    On_White='\033[47m'       # White

    # High Intensity
    IBlack='\033[0;90m'       # Black
    IRed='\033[0;91m'         # Red
    IGreen='\033[0;92m'       # Green
    IYellow='\033[0;93m'      # Yellow
    IBlue='\033[0;94m'        # Blue
    IPurple='\033[0;95m'      # Purple
    ICyan='\033[0;96m'        # Cyan
    IWhite='\033[0;97m'       # White

    # Bold High Intensity
    BIBlack='\033[1;90m'      # Black
    BIRed='\033[1;91m'        # Red
    BIGreen='\033[1;92m'      # Green
    BIYellow='\033[1;93m'     # Yellow
    BIBlue='\033[1;94m'       # Blue
    BIPurple='\033[1;95m'     # Purple
    BICyan='\033[1;96m'       # Cyan
    BIWhite='\033[1;97m'      # White

    # High Intensity backgrounds
    On_IBlack='\033[0;100m'   # Black
    On_IRed='\033[0;101m'     # Red
    On_IGreen='\033[0;102m'   # Green
    On_IYellow='\033[0;103m'  # Yellow
    On_IBlue='\033[0;104m'    # Blue
    On_IPurple='\033[0;105m'  # Purple
    On_ICyan='\033[0;106m'    # Cyan
    On_IWhite='\033[0;107m'   # White
}

## Call the colors() function
colors

## Uncomment if we are taking parameters into the script
if [ "$#" -eq "0" ]; then
  usage
else
    while [[ "$#" > "0" ]]
    do
        case $1 in
            (*=*) eval $1;;
        esac
    shift
    done

## Uncomment to test for required parameters
    if [ -z "$overcloudrcfile" ] || [ -z "$imagedir" ] || [ -z "$publickeyfile" ] || [ -z "$defaultSGID" ]; then
        usage
    fi
fi

## Uncomment to output all parameters to a log file
noLog "INFO ""
    overcloudrcfile     $overcloudrcfile
    imagedir            $imagedir
    publickeyfile       $publickeyfile
    defaultSGID         $defaultSGID"

####-----End Of Functions------------------------------------------------------

####-----Put Code Below Here---------------------------------------------------

preReqs

noLog "INFO -------------------------------------------------------------"
noLog "INFO Pre-requisites installed..."
noLog "INFO -------------------------------------------------------------"

### Sourcing The Overcloud rc file
source $overcloudrcfile;

## Testing the Environment before we configure it
noLog "INFO -------------------------------------------------------------"
noLog "INFO Let's test the environment to make sure its ready for us."
noLog "INFO -------------------------------------------------------------"

#### Test Connectivity
#### Test Namespace connectivity
#### Test if DHCP is working

## Create Our Flavors
noLog "INFO -------------------------------------------------------------"
noLog "INFO Creating our Flavors"
noLog "INFO -------------------------------------------------------------"
### m1 - Flavors that are not very big for Ubuntu and CentOS use
openstack flavor create m1.tiny --ram 1024 --disk 10 --vcpus 1
openstack flavor set --property aggregate_instance_extra_specs:regular=true m1.tiny
openstack flavor create m1.small --ram 2048 --disk 20 --vcpus 1
openstack flavor set --property aggregate_instance_extra_specs:regular=true m1.small
openstack flavor create m1.medium --ram 4096 --disk 20 --vcpus 2
openstack flavor set --property aggregate_instance_extra_specs:regular=true m1.medium
openstack flavor create m1.large --ram 8192 --disk 40 --vcpus 4
openstack flavor set --property aggregate_instance_extra_specs:regular=true m1.large
openstack flavor create m1.xlarge --ram 16384 --disk 60 --vcpus 8
openstack flavor set --property aggregate_instance_extra_specs:regular=true m1.xlarge
openstack flavor create m1.xxlarge --ram 16384 --disk 60 --vcpus 16
openstack flavor set --property aggregate_instance_extra_specs:regular=true m1.xxlarge
openstack flavor create m1.xxxlarge --ram 16384 --disk 160 --vcpus 24
openstack flavor set --property aggregate_instance_extra_specs:regular=true m1.xxxlarge

### m2 - Flavors that have disk big enough for BIG-IQ and BIG-IP
openstack flavor create m2.medium --ram 4096 --disk 160 --vcpus 2
openstack flavor set --property aggregate_instance_extra_specs:sriov=false --property aggregate_instance_extra_specs:dpdk=false m2.medium
openstack flavor create m2.large --ram 8192 --disk 160 --vcpus 4
openstack flavor set --property aggregate_instance_extra_specs:sriov=false --property aggregate_instance_extra_specs:dpdk=false m2.large
openstack flavor create m2.xlarge --ram 16384 --disk 160 --vcpus 8
openstack flavor set --property aggregate_instance_extra_specs:sriov=false --property aggregate_instance_extra_specs:dpdk=false m2.xlarge
openstack flavor create m2.xxlarge --ram 16384 --disk 160 --vcpus 16
openstack flavor set --property aggregate_instance_extra_specs:sriov=false --property aggregate_instance_extra_specs:dpdk=false m2.xxlarge
### m3 - Flavors that are setup for SRI-OV
openstack flavor create m3.large.sriov --ram 8192 --disk 160 --vcpus 4
openstack flavor set --property aggregate_instance_extra_specs:sriov=true --property hw:cpu_policy=dedicated --property hw:cpu_thread_policy=prefer --property hw:mem_page_size=any --property hw:numa_nodes=1 m3.large.sriov
openstack flavor create m3.xlarge.sriov --ram 16384 --disk 160 --vcpus 8
openstack flavor set --property aggregate_instance_extra_specs:sriov=true --property hw:cpu_policy=dedicated --property hw:cpu_thread_policy=prefer --property hw:mem_page_size=any --property hw:numa_nodes=1 m3.xlarge.sriov
openstack flavor create m3.xxlarge.sriov --ram 16384 --disk 160 --vcpus 16
openstack flavor set --property aggregate_instance_extra_specs:sriov=true --property hw:cpu_policy=dedicated --property hw:cpu_thread_policy=prefer --property hw:mem_page_size=any --property hw:numa_nodes=1 m3.xxlarge.sriov
openstack flavor create m3.xxxlarge.sriov --ram 16384 --disk 160 --vcpus 24
openstack flavor set --property aggregate_instance_extra_specs:sriov=true --property hw:cpu_policy=dedicated --property hw:cpu_thread_policy=prefer --property hw:mem_page_size=any --property hw:numa_nodes=1 m3.xxxlarge.sriov
### m4 - Flavors that are setup for DPDK
openstack flavor create m4.large.dpdk --ram 8192 --disk 160 --vcpus 4
openstack flavor set --property aggregate_instance_extra_specs:dpdk=true --property hw:cpu_policy=dedicated --property hw:mem_page_size=large m4.large.dpdk
openstack flavor create m4.xlarge.dpdk --ram 16384 --disk 160 --vcpus 8
openstack flavor set --property aggregate_instance_extra_specs:dpdk=true --property hw:cpu_policy=dedicated --property hw:mem_page_size=large m4.xlarge.dpdk
openstack flavor create m4.xxlarge.dpdk --ram 16384 --disk 160 --vcpus 16
openstack flavor set --property aggregate_instance_extra_specs:dpdk=true --property hw:cpu_policy=dedicated --property hw:mem_page_size=large m4.xxlarge.dpdk
openstack flavor create m4.xxxlarge.dpdk --ram 16384 --disk 160 --vcpus 24
openstack flavor set --property aggregate_instance_extra_specs:dpdk=true --property hw:cpu_policy=dedicated --property hw:mem_page_size=large m4.xxxlarge.dpdk
### m5 - Huge flavor
openstack flavor create m5.xxxlarge.sriov --ram 32768 --disk 160 --vcpus 24
openstack flavor set --property aggregate_instance_extra_specs:sriov=true --property hw:cpu_policy=dedicated --property hw:mem_page_size=large m5.xxxlarge.sriov
openstack flavor create m6.xlarge.sfr --ram 8192 --disk 160 --vcpus 8
openstack flavor set --property aggregate_instance_extra_specs:sfr=true --property hw:cpu_policy=dedicated --property hw:mem_page_size=any --property hw:cpu_thread_policy=prefer --property hw:numa_nodes=1 m6.xlarge.sfr

noLog "INFO -------------------------------------------------------------"
noLog "INFO Waiting 5 Seconds"
# sleep 5 &
# spinner "$!"
for i in {1..5};
    do 
        echo -ne "$i"'\r';
        sleep 1;
    done; 
echo
noLog "INFO -------------------------------------------------------------"

## Create Networks
noLog "INFO -------------------------------------------------------------"
noLog "INFO Creating base networks"
noLog "INFO -------------------------------------------------------------"
openstack network create public --external --provider-network-type vlan --provider-physical-network float --share --provider-segment 10
openstack network create pdn_ex --external --provider-network-type vlan --provider-physical-network provider --share --provider-segment 91
openstack network create pgw_ex --external --provider-network-type vlan --provider-physical-network provider --share --provider-segment 90
openstack network create pdn_dag_net_ex --external --provider-network-type vlan --provider-physical-network provider --share --provider-segment 100
openstack network create pgw_dag_net_ex --external --provider-network-type vlan --provider-physical-network provider --share --provider-segment 99
openstack network create mgmt_ts --provider-network-type vxlan
 
## Configure subnets
noLog "INFO -------------------------------------------------------------"
noLog "INFO Creating Subnets"
noLog "INFO -------------------------------------------------------------"
openstack subnet create public --network public --dhcp --allocation-pool start=10.144.184.66,end=10.144.184.100 --gateway 10.144.187.254 --subnet-range 10.144.184.0/22
openstack subnet create pdn_ex --network pdn_ex --subnet-range 192.168.4.0/23 --dhcp --allocation-pool start=192.168.4.76,end=192.168.4.100
openstack subnet create pgw_ex --network pgw_ex --subnet-range 192.168.2.0/23 --dhcp --allocation-pool start=192.168.2.76,end=192.168.2.100
openstack subnet create pdn_dag_net_ex --network pdn_dag_net_ex --subnet-range 192.168.12.0/23 --dhcp --allocation-pool start=192.168.12.76,end=192.168.12.100
openstack subnet create pgw_dag_net_ex --network pgw_dag_net_ex --subnet-range 192.168.10.0/23 --dhcp --allocation-pool start=192.168.10.76,end=192.168.10.100
openstack subnet create mgmt_ts --network mgmt_ts --gateway 10.10.2.1 --subnet-range 10.10.2.0/24 --dhcp --allocation-pool start=10.10.2.5,end=10.10.2.254
openstack subnet set mgmt_ts --dns-nameserver 172.27.1.1
openstack subnet set mgmt_ts --dns-nameserver 172.27.2.1 

noLog "INFO -------------------------------------------------------------"
noLog "INFO Sleeping 5 Seconds"
# sleep 5 &
# spinner "$!"
for i in {1..5};
    do 
        echo -ne "$i"'\r';
        sleep 1;
    done; 
echo
noLog "INFO -------------------------------------------------------------"

## Create the External Router
noLog "INFO -------------------------------------------------------------"
noLog "INFO Creating the External Router"
noLog "INFO -------------------------------------------------------------"
openstack router create router --no-ha
openstack router set router --external-gateway public
openstack router add subnet router mgmt_ts

noLog "INFO -------------------------------------------------------------"
noLog "INFO Sleeping 5 Seconds"
# sleep 5 &
# spinner "$!"
for i in {1..5};
    do 
        echo -ne "$i"'\r';
        sleep 1;
    done; 
echo
noLog "INFO -------------------------------------------------------------"

## Upload Images
startUpload=$(date +%s)
noLog "INFO -------------------------------------------------------------"
noLog "INFO Uploading Images this may take awhile..."
noLog "INFO -------------------------------------------------------------"
# openstack image create BIGIP-13.1.0.5 --disk-format qcow2 --file $imagedir/BIGIP-13.1.0.5-0.0.5.qcow2 --container-format bare --public
# openstack image create BIGIP-13.1.0.7 --disk-format qcow2 --file $imagedir/BIGIP-13.1.0.7-0.0.1.qcow2 --container-format bare --public
# openstack image create BIGIP-14.1.2-0.0.37 --disk-format qcow2 --file $imagedir/BIGIP-14.1.2-0.0.37.qcow2 --container-format bare --public
# openstack image create ubuntu-16.04-server --disk-format qcow2 --file $imagedir/ubuntu-16.04-server-cloudimg-amd64-20180228.1.qcow2 --container-format bare --public
# openstack image create ubuntu-18.04-server --disk-format qcow2 --file $imagedir/ubuntu-18.04-server-cloudimg-amd64-20190705.1.qcow2 --container-format bare --public
# openstack image create F5-VNF-Manager_v1.1.1.0 --disk-format qcow2 --file $imagedir/F5-VNF-Manager_v1.1.1.0.qcow2 --container-format bare --public
# openstack image create F5-VNF-Manager_v1.2.0.0 --disk-format qcow2 --file $imagedir/F5-VNF-Manager_v1.2.0.0.qcow2 --container-format bare --public
# openstack image create centos-7 --disk-format qcow2 --file $imagedir/CentOS-7-x86_64-GenericCloud.qcow2 --container-format bare --public
# openstack image create bigiq6.0.1 --disk-format qcow2 --file $imagedir/BIG-IQ-6.0.1.0.0.813.qcow2 --container-format bare --public
endUpload=$(date +%s)
## Use the preReqs() function to make sure bc is installed 
seconds=$(echo "$endUpload - $startUpload" | bc)
formattedSec=$(awk -v t=$seconds 'BEGIN{t=int(t*1000); printf "%d:%02d:%02d\n", t/3600000, t/60000%60, t/1000%60}')
noLog "INFO -------------------------------------------------------------"
noLog "INFO Uploaded images in $formattedSec..."
noLog "INFO -------------------------------------------------------------"
noLog "INFO -------------------------------------------------------------"
noLog "INFO Sleeping 5 Seconds"
# sleep 5 &
# spinner "$!"
for i in {1..5};
    do 
        echo -ne "$i"'\r';
        sleep 1;
    done; 
echo
noLog "INFO -------------------------------------------------------------"

## Create Security Group
noLog "INFO -------------------------------------------------------------"
noLog "INFO Creating the VNFM Security Group"
noLog "INFO -------------------------------------------------------------"
# openstack security group rule create --ethertype IPv4 --protocol ICMP --ingress --remote-ip 0.0.0.0/0 "$defaultSGID"
# openstack security group rule create --ethertype IPv4 --protocol TCP --ingress --remote-ip 0.0.0.0/0 "$defaultSGID"
# openstack security group rule create --ethertype IPv4 --protocol UDP --ingress --remote-ip 0.0.0.0/0 "$defaultSGID"
openstack security group create mgmt_sg_ts
openstack security group rule create --ethertype IPv4 --protocol ICMP --ingress --remote-ip 0.0.0.0/0 mgmt_sg_ts
openstack security group rule create --ethertype IPv4 --protocol TCP --ingress --remote-ip 0.0.0.0/0 mgmt_sg_ts
openstack security group rule create --ethertype IPv4 --protocol UDP --ingress --remote-ip 0.0.0.0/0 mgmt_sg_ts
openstack security group create ctrl_sg_ts
openstack security group rule create --ethertype IPv4 --protocol ICMP --ingress --remote-ip 0.0.0.0/0 ctrl_sg_ts
openstack security group rule create --ethertype IPv4 --protocol TCP --ingress --remote-ip 0.0.0.0/0 ctrl_sg_ts
openstack security group rule create --ethertype IPv4 --protocol UDP --ingress --remote-ip 0.0.0.0/0 ctrl_sg_ts
openstack security group create pgw_sg_ts
openstack security group rule create --ethertype IPv4 --protocol ICMP --ingress --remote-ip 0.0.0.0/0 pgw_sg_ts
openstack security group rule create --ethertype IPv4 --protocol TCP --ingress --remote-ip 0.0.0.0/0 pgw_sg_ts
openstack security group rule create --ethertype IPv4 --protocol UDP --ingress --remote-ip 0.0.0.0/0 pgw_sg_ts
openstack security group create pdn_sg_ts
openstack security group rule create --ethertype IPv4 --protocol ICMP --ingress --remote-ip 0.0.0.0/0 pdn_sg_ts
openstack security group rule create --ethertype IPv4 --protocol TCP --ingress --remote-ip 0.0.0.0/0 pdn_sg_ts
openstack security group rule create --ethertype IPv4 --protocol UDP --ingress --remote-ip 0.0.0.0/0 pdn_sg_ts
openstack security group create snmp_sg_ts
openstack security group rule create --ethertype IPv4 --protocol ICMP --ingress --remote-ip 0.0.0.0/0 snmp_sg_ts
openstack security group rule create --ethertype IPv4 --protocol TCP --ingress --remote-ip 0.0.0.0/0 snmp_sg_ts
openstack security group rule create --ethertype IPv4 --protocol UDP --ingress --remote-ip 0.0.0.0/0 snmp_sg_ts
openstack security group create bigiq_sg_ts
openstack security group rule create --ethertype IPv4 --protocol ICMP --ingress --remote-ip 0.0.0.0/0 bigiq_sg_ts
openstack security group rule create --ethertype IPv4 --protocol TCP --ingress --remote-ip 0.0.0.0/0 bigiq_sg_ts
openstack security group rule create --ethertype IPv4 --protocol UDP --ingress --remote-ip 0.0.0.0/0 bigiq_sg_ts

## Import SSH Public Key
noLog "INFO -------------------------------------------------------------"
noLog "INFO Importing the public key"
noLog "INFO -------------------------------------------------------------"
openstack keypair create stanley01 --public-key ~/Keys/Boulder_F5/stanley01.pub

## Create 2 Floating IP's
noLog "INFO -------------------------------------------------------------"
noLog "INFO Creating a floating IP for the test VM."
noLog "INFO -------------------------------------------------------------"
openstack floating ip create public

## Create Host Aggregate for DPDK
noLog "INFO -------------------------------------------------------------"
noLog "INFO Creating the dpdk aggregate."
noLog "INFO -------------------------------------------------------------"
openstack aggregate create dpdk --zone dpdk
openstack aggregate set --property sriov=false --property dpdk=true --property sfr=false --property regular=false dpdk
openstack aggregate create sriov --zone sriov
openstack aggregate set --property sriov=true --property dpdk=false --property sfr=false --property regluar=false sriov
openstack aggregate create regular --zone regular
openstack aggregate set --property sriov=false --property dpdk=false --property sfr=false --property regular=true regular
openstack aggregate create sfr --zone sfr
openstack aggregate set --property sriov=false --property dpdk=false --property sfr=true --property regular=false sfr

#openstack aggregate add host dpdk
#for i in $(openstack hypervisor list); do openstack overcloud plan delete $i; done; 
hypervisorList=$(openstack hypervisor list -f value -c "Hypervisor Hostname")

for hypervisor in $hypervisorList
do
    if [[ $hypervisor == *dpdk* ]]; then
        # add this to the dpdk aggregate
        openstack aggregate add host dpdk $hypervisor
    elif [[ $hypervisor == *sriov* ]]; then
        # add this to the sriov aggregate
        openstack aggregate add host sriov $hypervisor
    elif [[ $hypervisor == *sfr* ]]; then
        # add this to the sfr aggregate
        openstack aggregate add host sfr $hypervisor
    else
        # add it to the regluar aggregate
        openstack aggregate add host regular $hypervisor
    fi
done


## Setup Quota for Admin User
# openstack quota set --cores admin
noLog "INFO -------------------------------------------------------------"
noLog "INFO Make sure you change the quota for the admin project!!!"
noLog "INFO -------------------------------------------------------------"
noLog "INFO -------------------------------------------------------------"
noLog "INFO Sleeping 5 Seconds"
# sleep 5 &
# spinner "$!"
for i in {1..5};
    do 
        echo -ne "$i"'\r';
        sleep 1;
    done; 
echo
noLog "INFO -------------------------------------------------------------"

## Create Test VM
noLog "INFO -------------------------------------------------------------"
noLog "INFO Creating a test VM"
noLog "INFO -------------------------------------------------------------"
openstack server create --key-name stanley01 --image "CentOS-7-x86_64-GenericCloud" --flavor m1.tiny --network mgmt test
noLog "INFO Waiting 10 seconds for the VM to build..."
# sleep 10 &
# spinner "$!"
for i in {1..10};
    do 
        echo -ne "$i"'\r';
        sleep 1;
    done; 
echo
noLog "INFO -------------------------------------------------------------"
noLog "INFO -------------------------------------------------------------"
noLog "INFO Checking to see if the vm started:"
noLog "INFO -------------------------------------------------------------"
#openstack server show test


## Exiting
end=$(date +%s)
## Use the preReqs() function to make sure bc is installed 
seconds=$(echo "$end - $start" | bc)
formattedSec=$(awk -v t=$seconds 'BEGIN{t=int(t*1000); printf "%d:%02d:%02d\n", t/3600000, t/60000%60, t/1000%60}')
noLog "INFO -------------------------------------------------------------"
noLog "INFO Exiting in $formattedSec..."
noLog "INFO -------------------------------------------------------------"
exit 0