# vmware-kb79248 sts certificate repair
## Description
A play to download and call VMware support's scripts to check and fix expiring sts certificates on vmware vcenter appliances. If you want the knowledge base articles, see the [Reference Section](#Reference) 
### The Play's workflow 
1. Copy the `checksts.py` script from the KB to the designated appliance
2. Runs the script, and checks the output for expired certs
3. If the `fix_sts` flag has ben set
    1. Copy the `fixsts.sh` script from the KB to the appliance
    2. Check the `VMWARE_PASSWORD` environment varible, and if unset, prompt for the `administrator@vsphere.local` password
    3. Save a copy of the log file to `logs/<fdqn>/fix_sts_cert.log` file on your ansible workstation
    4. Restart services in order of master, PSC's, vCenters
4. Make your life easier and you look a rock star  

> ### ***<span style="color:red">Warning!</span>***
>- Mucking with sts signing certs can break your environment. Have backups and snapshots before begin
>- You're running code downloaded from the Internet, read the code first to get the warm and fuzzies. 
>- Until vmware support fixes the `fixsts.sh` script, a patched script is included that looks in the VCENTER_PASSWORD environment variable on your workstation or your Ansible Tower server. I dont claim this as my own, its from VMware. 
>- Tower or locally, the `administrator@vsphere.local` is passed around and unset in an environment variable. There is a possibility of it getting leaked. This is know behavior for ansible anyway.
>- I'm suggesting you generate and copy ssh keys to your vc. Understand the risks and mitigation before you do this.
>- Beyond this point, there be dragons. Proceed at your own risk.

>#### Notes
> This play only works with the VCSA appliance. Windows based vCenters are not supported.  


## Requirements
- A supported UNIX type OS (Linux, MacOS, etc)
- Ansible (developed against 2.9)
- vCenter 6.5 VCSA or later
- git
- a text editor of your choice
- the `administrator@vsphere.local` password
### To use the Vagrant file
- Vagrant
- One of following Virtualization Technologies:
    - Virtual Box
    - libvirt
    - Hyper-v
    - VMware Workstation
    - VMware Fusion

## Installation
### Unix
Use your favorite package manager. See the [Ansible Installation Guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html)

### Windows
Either Spin up a vm, or use the attached vagrant file to spin a Centos 7 environment. To install Vagrant, see the [Vagrant Install Guide](https://www.vagrantup.com/intro/getting-started/install.html). You'll also need one of the aforementioned hypervisors.

### Vagrant
Once Vagrant and a hypervisor has been installed, run `vagrant up`. Once the vmn is built, run `vagrant ssh` to log into the vm

## Configuration
You need to define your vcenter environment(s) in the `vcenters.ini` file. A block for SSO domain, and all the PSC's and vCenters need to be listed by fdqn. Because the scripts only need to be ran on one server with a PSC role, but all servers in the SSO domain need to restarted in order by role, there is an sts_role setting that need to be set. If the SSO  domain only has a single server, use the `sts_role=all` setting. If the domain is more complex, use the sts_role as shown below. 
### File Format
```ini
[sso_domain]
<appliance fdqn> sts_role=<sts_role>  
<next appliance fdqn> sts_role=<sts_role>
...
[next sso domain]
...
```
#### `sts_role` settings

| sts_role | when to use |
| --- | --- |
| all | Single vcenter with an embedded PSC |
| master | the Vcenter with embedded PSC or external PSC to run the cert scripts on |
| psc | external PSC |
| vcenter | vcenter server regardless of PSC |
>#### Note
> Only Set one `sts_role=master` per SSO domain.  


#### Sample file
```ini
[dev]  
dev_vc.corp.net sts_role=all  
[test]  
test_psc.corp.net sts_role=master  
test_vc.corp.net sts_role=vcenter  
[prod]  
prod_vc_east.corp.net sts_role=vcenter
prod_vc_west.corp.net sts_role=vcenter
prod_psc_east.corp.net sts_role=master
prod_psc_west.corp.net sts_role=psc
```
## Usage
### Before you begin
Please make sure your appliances are ansible ready first.
>#### Prerequisites 
>- ssh enabled on all vcenter appliances
>- bash set as default shell on all vcenter appliances, with `chsh -s /bin/bash`. See [vmware KB 2107727]((https://kb.vmware.com/s/article/2107727))  
>- `vcenter.ini` file properly configured  
>#### Optional, but nice  
>- If you don't have an ssh keypair, create a set with `ssh-keygen`. Please Understand the risks first.
>- copy ssh keys, if you have them, with `ssh-copy-id root@<your fdqn> -o PreferredAuthentications=password -o PubkeyAuthentication=no`
### Run in check mode
Just a simple `ansible-playbook apply_kb.yml` is all you need.

### Run in fix mode
Run `ansible-playbook -e "fix_sts=True"`. If you use `sso_domain` option, that will stack like so: `ansible-playbook -e "fix_sts=True sso_domain=dev"`

### Options
| option | usage |
| --- | --- |
| `-k` | prompt for ssh password, not needed if you have ssh keys setup | 
| `-v` | show verbose output of `checksts.py` script |
| `-e "sso_domain=<blah>` | target only one SSO domain, as defined in `vcenters.ini` |

### Ansible Tower
To use the play in Tower, create a vcenter credental with a username of `administrator@vsphere.local` and the password. Attach the credential to the job template as normally. You will also need you SSH credentials attached as well. Tower will unpack the encrypted value from the data, and the password into `VMWARE_PASSWORD` env variable. 

## Reference
[vmware kb 79248](https://kb.vmware.com/s/article/79248)  
[vmware kb 76719](https://kb.vmware.com/s/article/79248)  
[vmware kb 2107727](https://kb.vmware.com/s/article/2107727)  
[Ansible Installation Guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html)  
[Vagrant Install Guide](https://www.vagrantup.com/intro/getting-started/install.html)  

## Legal
I am in no away affiliated with VMware, nor did I write the scripts. I just an ansible play to run them. Use this as your own peril with good backups and snapshots. Don't blame me if this burns down your center environment, you were warned. I take no responsibility or liability.

Trademarks and Copyright are propertys of their respective owners.