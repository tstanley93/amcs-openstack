# SP Lab VNMF Project
This space is dedicated to the VNFM project and its associated information.

## Resources
- [F5 Resources](https://gitlab.f5net.com/spsolutions/infra/blob/master/f5-resources.md)
- [Router Resources](https://gitlab.f5net.com/spsolutions/infra/blob/master/router-resources.md)
- [Switch Resources](https://gitlab.f5net.com/spsolutions/infra/blob/master/switch-resources.md)
- [Server Resources](https://gitlab.f5net.com/spsolutions/infra/blob/master/server-resources.md)

## Configuration
- Red Hat Enterprise Linux 7.5 Install
  - [Install Readme](rhel-install/README.md)
  - [RHEL Post-Install Script](rhel-install/rhel-post-install.sh)
- Red Hat OpenStack Platform 10 Install
  - [Install Readme](rhosp-install/README.md)
  - [RHOSP Pre-Install Script](rhosp-install/rhosp-pre-install.sh)
  - [RHOSP Install Script](rhosp-install/rhosp-install.sh)
  - [RHOSP undercloud.conf](rhosp-install/undercloud.conf)
  - [RHOSP instanckenv.json](rhosp-install/instackenv.json)
  - [Red Hat OpenStack Platform 10 Documentation](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/10/)
- Cloudify Install
  - [Readme](cloudify-install/README.md)
  - Cloudify [inputs.yaml](cloudify-install/inputs.yaml)

## Topology
### networks
- IMPI/Management: 10.146.92.0/24
- Provisioning: 10.146.94.0/23
- External: 10.146.128.0/23
