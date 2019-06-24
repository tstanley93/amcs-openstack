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
    To run this you will need to have installed the following packages;
        - bc [sudo apt-get install bc]
        - OpenStack python command line [see: https://docs.openstack.org/newton/user-guide/common/cli-install-openstack-command-line-clients.html]
    "$IRed"Note:\033[0m Please be careful of the parameter construction, it must match exactly to work...
    Example: /home/stack/rhosp-post-install.sh stackrcfile=/home/stack/stackrc overcloudrcfile=/home/stack/thomas14rc imagedir=/home/stack/vm_images

    Parameters:
    "$IYellow"stackrcfile=\033[0m<the full path to the undercloud stackrc file [/home/stack/stackrc]>
    "$IYellow"overcloudrcfile=\033[0m<the full path to the overlcoud rc file [/home/stack/overcloudrc]>
    "$IYellow"imagedir=\033[0m<the full path to the directory containing the images [/home/stack/images/]>

    "
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
    # doLog "INFO INFO some info message"
    # doLog "INFO DEBUG some debug message"
    # doLog "INFO WARN some warning message"
    # doLog "INFO ERROR some really ERROR message"
    # doLog "INFO FATAL some really fatal message"
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
    echo " [$type_of_msg] `date "+%Y.%m.%d-%H:%M:%S %Z"` ""$msg" >> $log_file
}

spinner() {
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
        doLog "WARN bc is not installed..."
        echo "Do you want me to install it? [Y/n]"
        read yn
        if [[ $yn = Y || y ]]; then
            sudo apt install bc -yn
        else
            doLog "WARN Exiting Script"
            doLog "WARN The program bc must be installed to use this script."
            exit 101
        fi
    fi

    result=$(( openstack --version ) 2>&1)

    if [[ $result == *"The program"* ]]; then
        doLog "WARN Python OpenStackClient is not installed..."
        echo "Do you want me to install it? [Y/n]"
        read yn
        if [[ $yn = Y || y ]]; then
            sudo apt install python3-openstackclient -yn
        else
            doLog "WARN Exiting Script"
            doLog "WARN The program python openstackclient must be installed to use this script."
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
    if [ -z "$stackrcfile" ] || [ -z "$overcloudrcfile" ] || [ -z "$imagedir" ]; then
        usage
    fi
fi

## Uncomment to output all parameters to a log file
doLog "INFO ""
    stackrcfile         $stackrcfile
    overcloudrcfile     $overcloudrcfile
    imagedir            $imagedir"

####-----End Of Functions------------------------------------------------------

####-----Put Code Below Here---------------------------------------------------

preReqs

noLog "INFO -------------------------------------------------------------"
noLog "INFO Pre-requisites installed..."
noLog "INFO -------------------------------------------------------------"

source /home/stack/$stackrcfile;

# serverIP=$(openstack server list -c Networks -f value)
# for node in $serverIP
# do
#     node=${node##*=}
#     #echo $node
#     noLog "INFO" $(ssh -o "StrictHostKeyChecking no" heat-admin@"$node" "sudo sed -i 's/#disk_allocation_ratio=0.0/disk_allocation_ratio=2.0/g' /etc/nova/nova.conf")
#     noLog "INFO" $(ssh -o "StrictHostKeyChecking no" heat-admin@"$node" "sudo sed -i 's/metering_time_to_live=-1/metering_time_to_live=604800/g' /etc/ceilometer/ceilometer.conf")
#     noLog "INFO" $(ssh -o "StrictHostKeyChecking no" heat-admin@"$node" "sudo sed -i 's/event_time_to_live=-1/event_time_to_live=604800/g' /etc/ceilometer/ceilometer.conf")
#     noLog "INFO" $(ssh -o "StrictHostKeyChecking no" heat-admin@"$node" "sudo systemctl restart openstack-nova-compute.service")
#     noLog "INFO" $(ssh -o "StrictHostKeyChecking no" heat-admin@"$node" "sudo systemctl restart openstack-ceilometer-compute.service")
# done

## Create Flavors
source /home/stack/$overcloudrcfile;
openstack flavor create m1.tiny --ram 1024 --disk 10 --vcpus 1
openstack flavor create m1.small --ram 2048 --disk 20 --vcpus 1
openstack flavor create m1.medium --ram 4096 --disk 20 --vcpus 2
openstack flavor create m2.medium --ram 4096 --disk 160 --vcpus 2
openstack flavor create m1.large --ram 8192 --disk 40 --vcpus 4
openstack flavor create m2.large --ram 8192 --disk 160 --vcpus 4
openstack flavor create m3.large.sriov --ram 8192 --disk 160 --vcpus 4
openstack flavor set --property "aggregate_instance_extra_specs:sriov"="true" --property hw:cpu_policy=dedicated --property hw:mem_page_size=large m3.large.sriov
openstack flavor create m1.xlarge --ram 16384 --disk 60 --vcpus 8
openstack flavor create m2.xlarge --ram 16384 --disk 160 --vcpus 8
openstack flavor create m3.xlarge.sriov --ram 16384 --disk 160 --vcpus 8
openstack flavor set --property "aggregate_instance_extra_specs:sriov"="true" --property hw:cpu_policy=dedicated --property hw:mem_page_size=large m3.xlarge.sriov
openstack flavor create m1.xxlarge --ram 16384 --disk 60 --vcpus 16
openstack flavor create m2.xxlarge --ram 16384 --disk 160 --vcpus 16
openstack flavor create m3.xxlarge.sriov --ram 16384 --disk 160 --vcpus 16
openstack flavor set --property "aggregate_instance_extra_specs:sriov"="true" --property hw:cpu_policy=dedicated --property hw:mem_page_size=large m3.xxlarge.sriov
openstack flavor create m1.xxxlarge --ram 16384 --disk 160 --vcpus 24
openstack flavor create m2.xxxlarge.sriov --ram 16384 --disk 160 --vcpus 24
openstack flavor set --property "aggregate_instance_extra_specs:sriov"="true" --property hw:cpu_policy=dedicated --property hw:mem_page_size=large m2.xxxlarge.sriov

## Create Networks
openstack network create public --default --external --provider-network-type vlan --provider-physical-network datacentre --share --provider-segment 10
openstack network create pdn --external --provider-network-type vlan --provider-physical-network datacentre --share --provider-segment 91
openstack network create pgw --external --provider-network-type vlan --provider-physical-network datacentre --share --provider-segment 90
openstack network create pdn_dag_net --external --provider-network-type vlan --provider-physical-network datacentre --share --provider-segment 100
openstack network create pgw_dag_net --external --provider-network-type vlan --provider-physical-network datacentre --share --provider-segment 99
 
## Configure subnets
openstack subnet create public --network public --dhcp --allocation-pool start=10.146.94.210,end=10.146.95.250 --gateway 10.146.95.254 --subnet-range 10.146.94.0/23
openstack subnet create pdn --network pdn --gateway 192.168.4.1 --subnet-range 192.168.4.0/23 --dhcp --allocation-pool start=192.168.4.50,end=192.168.4.75
openstack subnet create pgw --network pgw --gateway 192.168.2.1 --subnet-range 192.168.2.0/23 --dhcp --allocation-pool start=192.168.2.50,end=192.168.2.75
openstack subnet create pdn_dag_net --network pdn_dag_net --gateway 192.168.12.1 --subnet-range 192.168.12.0/23 --dhcp --allocation-pool start=192.168.12.50,end=192.168.12.75
openstack subnet create pgw_dag_net --network pgw_dag_net --gateway 192.168.10.1 --subnet-range 192.168.10.0/23 --dhcp --allocation-pool start=192.168.10.50,end=192.168.10.75

## Upload Images
# openstack image create BIGIP-13.1.0.5-0.0.5 --disk-format qcow2 --file $imagedir/BIGIP-13.1.0.5-0.0.5.qcow2 --public
# openstack image create ubuntu-16.04-server-cloudimg-amd64-20180228.1 --disk-format qcow2 --file $imagedir/ubuntu-16.04-server-cloudimg-amd64-20180228.1.qcow2 --public
# openstack image create vnfm1.0.1.0 --disk-format qcow2 --file $imagedir/F5-VNF-Manager_v1.0.1.0.qcow2 --public
# openstack image create centos --disk-format qcow2 --file $imagedir/CentOS-7-x86_64-GenericCloud.qcow2 --public
# openstack image create bigiq6.0.1 --disk-format qcow2 --file $imagedir/BIG-IQ-6.0.1.0.0.813.qcow2 --public


## Exiting
end=$(date +%s)
## Use the preReqs() function to make sure bc is installed 
seconds=$(echo "$end - $start" | bc)
formattedSec=$(awk -v t=$seconds 'BEGIN{t=int(t*1000); printf "%d:%02d:%02d\n", t/3600000, t/60000%60, t/1000%60}')
noLog "INFO -------------------------------------------------------------"
noLog "INFO Exiting in $formattedSec..."
noLog "INFO -------------------------------------------------------------"
exit 0