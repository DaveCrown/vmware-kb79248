# vmware-kb79248 sts certificate repair
## Description
A play to download and call VMware support's scripts to check, and if necessary fix, expiring sts certificates on vmware vcenter appliances. If you want the knowledge base articles, see the [Reference Section](#Reference) 
### The Play's workflow 
1. Copy the `checksts.py` script from the KB to the designated appliance
2. Runs the script, and checks the output for expired certs
3. If the `fix_sts` flag has ben set
    1. Copy the `fixsts.sh` script from the KB to the appliance
    2. Patch the script to use a password stuffed into the `VMWARE_PASSWORD`
    3. Check the local workstation/Tower for `VMWARE_PASSWORD` environment varible, and if unset, prompt for the `administrator@vsphere.local` password
    4. Save a copy of the log file to `logs/<fdqn>/fix_sts_cert.log` file on your ansible workstation
    5. Restart services in order of master, PSC's, vCenters
4. Make your life easier and you look a rock star  

> ### ***<span style="color:red">Warning!</span>***
>- Mucking with sts signing certs can break your environment. Have backups and snapshots before begin.
>- You're running code downloaded from the Internet, read the code first to get that warm and fuzzy feeling. 
>- Until I can get vmware support to fix the `fixsts.sh` script, I patch the script to include a check that the `VCENTER_PASSWORD` environment variable set on the VCSA. This is done temporarily by either pulling it from the env var on your workstation or Ansible Tower server, or prompting you for it. I don't claim this script as my own, its from VMware. 
>- Tower or locally, the `administrator@vsphere.local` is passed around and unset in an environment variable. There is a possibility of it getting leaked. While this is standard operating procedure for Tower, you need to be aware of this.  
>- I'm suggesting you generate and copy ssh keys to your vc. Understand the risks and mitigation before you do this.
>- Beyond this point, there be dragons. Proceed at your own risk.
>#### Notes
> This play only works with the VCSA appliance. Windows based vCenters are not supported.  


## Requirements
- **Backups and Snapshots**
- A supported UNIX type OS (Linux, MacOS, etc)
- Ansible (developed against 2.9)
- vCenter 6.5 VCSA or later
- git
- a text editor of your choice
- the `administrator@vsphere.local` password
- the `root` os passwords for all the vcsa's you want to use this with
### To use the Vagrant file
- Vagrant
- One of following Virtualization Technologies:
    - Virtual Box
    - libvirt
    - Hyper-v
    - VMware Workstation
    - VMware Fusion

## Installation
### git clone
Start with cloning this to your local workstation with `git clone https://github.com/DaveCrown/vmware-kb79248.git` and `cd vmware-kb79248`

### Unix
Use your favorite package manager. See the [Ansible Installation Guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html)

### Windows
Either spin up a vm, or use the attached vagrant file to spin a Centos 7 environment. The vagrant fil will call the included `install.yml` play to configure the environment with Ansible, Git, and a few other goodies. To install Vagrant, see the [Vagrant Install Guide](https://www.vagrantup.com/intro/getting-started/install.html). You'll also need one of the aforementioned hypervisors.

### Vagrant
The included Vagrant file will spin up a Centos 7 VM, and use the `install.yml` play to install all the required software, copy all the file in this repository over to the `/vagrant` directory. Once Vagrant and a hypervisor has been installed, run `vagrant up`. Once the vmn is built, run `vagrant ssh` to log into the vm. Once in, `cd /vagrant` to get to the files.

## Configuration
You need to define your vcenter environment(s) in the `vcenters.ini` file. It consists of a block for each SSO domain, with all the PSC's and vCenters need to be listed by fdqn with an `sts_role=<role>`. Because the scripts only need to be ran on one server with a PSC role, but all servers in the SSO domain need to restarted in order by role, there is an sts_role setting that need to be set. If the SSO  domain only has a single server, use the `sts_role=all` setting. If the domain is more complex, use the sts_role as shown below. You can (and should), put multiple SSO Domains into one file.

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
>#### Notes
>- Only Set one `sts_role=master` per SSO domain. 
>- The order of hosts in the SSO domain group doesn't matter. `sts_role` enforces the restart order.


#### Sample `vcenters.ini` file
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
>- bash set as default shell on all vcenter appliances, with `chsh -s /bin/bash`. See [vmware KB 2107727]((https://kb.vmware.com/s/article/2107727)). Steps 1 through 5 need to be completed. I like to leave `/bin/bash` as my shell.  
>> #### Required
>- ***Backups!***
>- ssh enabled on all vcenter appliances
>- this git repo cloned to your workstation or as a project in tower.
>- bash set as default shell on all vcenter appliances, with `chsh -s /bin/bash`. See [vmware KB 2107727]((https://kb.vmware.com/s/article/2107727))  
>- `vcenters.ini` file properly configured  
>>#### Optional, but nice  
>- If you don't have an ssh keypair, create a set with `ssh-keygen`. Please Understand the risks first.
>- Copy your ssh keys, if you have them, with `ssh-copy-id root@<your fdqn> -o PreferredAuthentications=password -o PubkeyAuthentication=no`
### Run in check mode

#### No sshkeys
Just a simple `ansible-playbook -k apply_kb.yml` is all you need. The flag `-k` will instruct Ansible to prompt for the password.
#### With ssh keys
Call `ansible-playbook apply_kb.yml` without the `-k`.
### Run in fix mode
Run `ansible-playbook -e "fix_sts=True"`. If you use `sso_domain` option, that will stack like so: `ansible-playbook -e "fix_sts=True sso_domain=dev"`  
If you want/need to be prompted for the root ssh password, use the `-k` as shown above.

### Options
| option | usage |
| --- | --- |
| `-k` | prompt for ssh password, not needed if you have ssh keys setup | 
| `-v` | show verbose output of `checksts.py` script |
| `-e "sso_domain=<blah>` | target only one SSO domain, as defined in `vcenters.ini` |
| `-e "fix_sts=True"` | enable automatic repair of sts signing cert |

### Ansible Tower
To use the play in Tower, create a vcenter credential with a username of `administrator@vsphere.local` and the password. Attach the credential to the job template as normally. You will also need you SSH credentials attached as well. Tower will unpack the encrypted value from the data, and the password into `VMWARE_PASSWORD` env variable. The `fix_sts` flag gets set in the `Extra Variables` block. The vcenters.ini file is your inventory file for the project.

## Reference
[vmware kb 79248](https://kb.vmware.com/s/article/79248)  
[vmware kb 76719](https://kb.vmware.com/s/article/76719)  
[vmware kb 2107727](https://kb.vmware.com/s/article/2107727)  
[Ansible Installation Guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html)  
[Vagrant Install Guide](https://www.vagrantup.com/intro/getting-started/install.html)  

## Legal
I am in no away affiliated with VMware, nor did I write the scripts. I just an ansible play to run them. Use this as your own peril with good backups and snapshots. Don't blame me if this burns down your center environment, you were warned. I take no responsibility or liability.

Trademarks and Copyrights are properties of their respective owners.