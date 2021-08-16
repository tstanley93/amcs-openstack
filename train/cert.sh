#!/bin/bash
set -e
start=$(date +%s)
#trap "set +x; sleep 1; set -x" DEBUG
#export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin/"
#IP_REGEX='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'

####-----Functions-------------------------------------------------------------

usage() { 
    printf "%b" "    Usage: $0

    This script will create a valid certificate that will work with modern browsers.

    Pre-Requisites:
    To run this you will need to have installed the following packages;
        - bc [sudo apt-get install bc]
        - openssl [sudo apt-get install openssl]
    "$IRed"Note:\033[0m Please be careful of the parameter construction, it must match exactly to work...
    Example: /home/stack/rhosp-post-install.sh stackrcfile=/home/stack/stackrc overcloudrcfile=/home/stack/thomas14rc imagedir=/home/stack/vm_images

    Parameters:
    "$IYellow"CNName=\033[0m<The common name of the certificate.  This can be an IP address or an FQDN. Example: [www.example.com]>
    "$IYellow"CertPath=\033[0m<Where you want the cert files stored, make sure to include the trailing slash. Example: [/home/username/certs/]>
    "$IYellow"CaCertPath=\033[0m<The path to the ca cert file, make sure to include the file name at the end. Example: [/home/username/certs/ca.crt]>
    "$IYellow"CaCertKeyPath=\033[0m<The path to the ca key file, make sure to include the file name at the end. Example: [/home/username/certs/ca.key.pem]>
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
    if [ -z "$CNName" ]; then
        usage
    fi
    if [ -z "$CertPath" ]; then
        usage
    fi
    if [ -z "$CaCertPath" ]; then
        usage
    fi
    if [ -z "$CaCertKeyPath" ]; then
        usage
    fi
fi

## Uncomment to output all parameters to a log file
noLog "INFO ""
    CNName         $CNName
    CertPath       $CertPath
    CaCertPath     $CaCertPath
    CaCertKeyPath  $CaCertKeyPath"

####-----End Of Functions------------------------------------------------------

####-----Put Code Below Here---------------------------------------------------


###  Generate private key
openssl genrsa -out "$CertPath""$CNName".key.pem 2048

###  Create the .cnf template file
cat << EOF | tee "$CertPath""$CNName".cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
C = US
ST = Washington
L = Seattle
O = F5 Networks
OU = Product Management
CN = "$CNName"
[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS = os16dir.pdsea.f5net.com
#DNS.1 = registry.splab.pdsea.f5net.com
#DNS.2 = <servername2.domain.com>
#DNS.3 = <servername3.domain.com>
#DNS.4 = <servername4.domain.com>
IP.1 = 10.146.171.13
EOF

###  Edit the .cnf
vi "$CertPath""$CNName".cnf

### Generate the server cert signing request
openssl req \
-sha256 \
-new \
-key "$CertPath""$CNName".key.pem \
-config "$CertPath""$CNName".cnf \
-out "$CertPath""$CNName".csr

### Verify the CSR
openssl req -text -noout -verify -in "$CertPath""$CNName".csr

### Pause and wait for a keystroke to continue:
read -p ""$IYellow"Does the above look correct?\033[0m [Yes to continue No to exit]:" ans_yn
case "$ans_yn" in
    [Yy]|[Yy][Ee][Ss]);;
    *) exit 3;;
esac

### Generate the server certificate
openssl \
x509 \
-req \
-extensions v3_req \
-days 3650 \
-sha256 \
-in "$CertPath""$CNName".csr \
-CA "$CaCertPath" \
-CAkey "$CaCertKeyPath" \
-CAcreateserial \
-out "$CertPath""$CNName".crt \
-extfile "$CertPath""$CNName".cnf

### Verify the Certificate
openssl x509 -in "$CertPath""$CNName".crt -text -noout

#### Combine Cert and Key
cat "$CertPath""$CNName".crt "$CertPath""$CNName".key.pem > "$CertPath""$CNName".pem