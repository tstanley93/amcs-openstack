.PHONY: images

deploy:
	@echo "deploying overcloud..."
	openstack overcloud deploy \
		--templates \
		-e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
		-e ~/templates/network-environment.yaml \
		-e ~/templates/vnf.yaml \
		--timeout 3600 \
    		--ntp-server time.google.com
		#-e ~/templates/network-isolation.yaml \
		#-e ~/templates/storage-environment.yaml \

monitor:
	source ~/stackrc
	openstack stack list --nested

images:
	@echo "Downloading and installing images..."
	sudo yum install rhosp-director-images rhosp-director-images-ipa
	cd ~/images && for i in /usr/share/rhosp-director-images/overcloud-full-latest-10.0.tar /usr/share/rhosp-director-images/ironic-python-agent-latest-10.0.tar; do tar -xvf $$i; done
	source ~/stackrc && openstack overcloud image upload --image-path /home/stack/images/
	source ~/stackrc && openstack image list
	ls -l /httpboot

destroy:
	@echo "Deleting overcloud..."
	source ~/stackrc && openstack stack list
	source ~/stackrc && openstack stack delete --wait overcloud
	source ~/stackrc && openstack overcloud plan delete overcloud
	source ~/stackrc && swift delete overcloud-swift-rings
	source ~/stackrc && openstack stack list
