#!/bin/bash
## Verify that podman is loaded and we have access to it..
if ! sudo podman version > /dev/null 2>&1; then
    sudo systemctl start podman;
    if ! sudo podman version > /dev/null 2>&1; then
        exit 1;
    fi
fi
##  Determine if the F5 Orchestrator is already installed and if it is running
container_name="_container_name_"
if [ "$(podman ps -qa -f name=$container_name)" ]; then
    if [ "$(podman ps -qa -f status=exited -f name=$container_name)" ]; then
        echo "Removing old orchestrator container then running a new one."
        podman rm $container_name
    else
        echo "Container is running. Nothing to do."
        exit 0
    fi
else
    echo "Orchestrator container not found. Running orchestrator container now."
fi
## Run the container
sudo podman run -d -i -t \
-e TZ=America/Los_Angeles \
-e ACCEPT_EULA=Y \
-e DEBUG=Y \
--net=host \
--mount type=bind,src=/lib/modules,target=/lib/modules \
--mount type=bind,src=/usr/src,target=/usr/src \
--mount type=bind,src=/dev,target=/dev \
--mount type=bind,src=/var/log,target=/var/log \
--mount type=bind,src=/var/lib,target=/var/lib \
--mount type=bind,src=/usr/share/hwdata,target=/usr/share/hwdata \
-p 8443:8443 \
--privileged=true \
--name $container_name \
--tls-verify false \
_registry_name_:_registry_port__repo_path_:_repo_tag_
## Check that the container actually loaded
if [ "$(podman ps -qa -f name=$container_name)" ]; then
    if [ "$(podman ps -qa -f status=exited -f name=$container_name)" ]; then
        echo "Container failed exiting."
        exit 2
    else
        echo "Container is running. Nothing to do."
    fi
else
    echo "Orchestrator container did not load exiting."
    exit 2
fi
##  Wait for the orchestrator to finish loading while monitoring for errors
COUNT=3600
while [ $COUNT -gt 0 ]; do
    logs=$(podman logs $container_name --tail 7)
    if printf '%s\0' "$logs" | grep --quiet "Log Level: error"; then
        if printf '%s\0' "$logs" | grep --quiet "Error Message: The loaded image is not latest"; then
            #This error is fine. It should be just a warning instead of both an error and warning.
            echo "Bitfile is not the latest. Loading a new bitfile, which can take ~40 minutes"
        else
            echo "Something went wrong! Check the podman logs."
            exit 3
        fi
    fi
    if printf '%s\0' "$logs" | grep --quiet "Failed to get resource path"; then
        echo "Something went wrong! Check the podman logs."
        exit 4
    fi
    if printf '%s\0' "$logs" | grep --quiet "Enable Network Interface "; then
        if printf '%s\0' "$logs" | grep --quiet "Status: Passed"; then
            echo "Smartnic Orchestrator successfully installed."
            break 2
        fi
    fi
    sleep 1
   ((COUNT=COUNT-1))
done
if ((COUNT == 0)); then
    echo "Container timed out. Check the container logs for more info."
    exit 5
fi
## Load the vfio-pci driver so that the OS can pass through the F5 SmartNIC VF's
lspci=$(lspci -nnd :101)
lspci_arr=("$lspci")
primary_vf="0000:"${lspci_arr[15]}
secondary_vf="0000:"${lspci_arr[0]}
sudo driverctl set-override "${primary_vf}" vfio-pci
sudo driverctl set-override "${secondary_vf}" vfio-pci
## Verify the vfio-pci driver loaded successfully for each F5 SmartNIC VF
primary_vf_driver=$(lspci -ks "$primary_vf")
secondary_vf_driver=$(lspci -ks "$secondary_vf")
if printf '%s\0' "$primary_vf_driver" | grep --quiet "Kernel driver in use: vfio-pci"; then
    echo "Vfio-pci driver loaded on first VF."
else
    echo "[ERROR] Vfio-pci driver not loaded on first VF"
fi
if printf '%s\0' "$secondary_vf_driver" | grep --quiet "Kernel driver in use: vfio-pci"; then
    echo "Vfio-pci driver loaded on second VF."
else
    echo "[ERROR] Vfio-pci driver not loaded on second VF"
fi
## Configure F5 Orchestrator to automatically restart on reboot of the compute node
if [ -f /etc/systemd/system/f5smartnic.service ]; then
    echo "The service is already defined"
else
    touch /etc/systemd/system/f5smartnic.service
    cat << EOF | sudo tee /etc/systemd/system/f5smartnic.service
    [Unit]
    Description=F5 SmartNIC Orchestrator Tool Container
    Requires=docker.service
    After=docker.service

    [Service]
    Restart=always
    ExecStart=/usr/bin/docker start -a --name $container_name
    ExecStop=/usr/bin/docker stop -t 2 --name $container_name

    [Install]
    WantedBy=local.target
EOF
    sudo systemctl daemon-reload
    # sudo systemctl start f5smartnic.service
    sudo systemctl enable f5smartnic.service
fi
## Remove registry as insecure registry for security
cat << EOF | tee /etc/podman/daemon.json
{}
EOF
## If we made it to here then all went well!  So let's exit nicley!
exit 0