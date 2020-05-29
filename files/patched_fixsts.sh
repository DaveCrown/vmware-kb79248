#!/bin/bash
# Run this from the affected PSC/VC
# Luciano Delorenzi [ldelorenzi@vmware.com] - 1/2/2020

# NOTE: This works on external and embedded PSCs
# This script will do the following
# 1: Regenerate STS certificate
#
#
# What is needed?
# 1: Offline snapshots of VCs/PSCs
# 2: SSO Admin Password



echo "NOTE: This works on external and embedded PSCs"
echo "This script will do the following"
echo "1: Regenerate STS certificate"
echo "What is needed?"
echo "1: Offline snapshots of VCs/PSCs"
echo "2: SSO Admin Password"
echo "IMPORTANT: This script should only be run on a single PSC per SSO domain"


mkdir -p /tmp/vmware-fixsts
SCRIPTPATH="/tmp/vmware-fixsts"
LOGFILE="$SCRIPTPATH/fix_sts_cert.log"

echo "==================================" | tee -a $LOGFILE
echo "Resetting STS certificate for $HOSTNAME started on $(date)" | tee -a $LOGFILE
echo ""| tee -a $LOGFILE
echo ""
DN=$(/opt/likewise/bin/lwregshell list_values '[HKEY_THIS_MACHINE\Services\vmdir]' | grep dcAccountDN | awk '{$1=$2=$3="";print $0}'|tr -d '"'|sed -e 's/^[ \t]*//')
echo "Detected DN: $DN" | tee -a $LOGFILE 
PNID=$(/opt/likewise/bin/lwregshell list_values '[HKEY_THIS_MACHINE\Services\vmafd\Parameters]' | grep PNID | awk '{print $4}'|tr -d '"')
echo "Detected PNID: $PNID" | tee -a $LOGFILE
PSC=$(/opt/likewise/bin/lwregshell list_values '[HKEY_THIS_MACHINE\Services\vmafd\Parameters]' | grep DCName | awk '{print $4}'|tr -d '"')
echo "Detected PSC: $PSC" | tee -a $LOGFILE
DOMAIN=$(/opt/likewise/bin/lwregshell list_values '[HKEY_THIS_MACHINE\Services\vmafd\Parameters]' | grep DomainName | awk '{print $4}'|tr -d '"')
echo "Detected SSO domain name: $DOMAIN" | tee -a $LOGFILE
SITE=$(/opt/likewise/bin/lwregshell list_values '[HKEY_THIS_MACHINE\Services\vmafd\Parameters]' | grep SiteName | awk '{print $4}'|tr -d '"')
MACHINEID=$(/usr/lib/vmware-vmafd/bin/vmafd-cli get-machine-id --server-name localhost)
echo "Detected Machine ID: $MACHINEID" | tee -a $LOGFILE
IPADDRESS=$(ifconfig | grep eth0 -A1 | grep "inet addr" | awk -F ':' '{print $2}' | awk -F ' ' '{print $1}')
echo "Detected IP Address: $IPADDRESS" | tee -a $LOGFILE
DOMAINCN="dc=$(echo "$DOMAIN" | sed 's/\./,dc=/g')"
echo "Domain CN: $DOMAINCN"
ADMIN="cn=administrator,cn=users,$DOMAINCN"
USERNAME="administrator@${DOMAIN^^}"
ROOTCERTDATE=$(openssl x509  -in /var/lib/vmware/vmca/root.cer -text | grep "Not After" | awk -F ' ' '{print $7,$4,$5}')
TODAYSDATE=$(date | awk -F ' ' '{print $6,$2,$3}')

echo "#" > $SCRIPTPATH/certool.cfg
echo "# Template file for a CSR request" >> $SCRIPTPATH/certool.cfg
echo "#" >> certool.cfg
echo "# Country is needed and has to be 2 characters" >> $SCRIPTPATH/certool.cfg
echo "Country = DS" >> $SCRIPTPATH/certool.cfg
echo "Name = $PNID" >> $SCRIPTPATH/certool.cfg
echo "Organization = VMware" >> $SCRIPTPATH/certool.cfg
echo "OrgUnit = VMware" >> $SCRIPTPATH/certool.cfg
echo "State = VMware" >> $SCRIPTPATH/certool.cfg
echo "Locality = VMware" >> $SCRIPTPATH/certool.cfg
echo "IPAddress = $IPADDRESS" >> $SCRIPTPATH/certool.cfg
echo "Email = email@acme.com" >> $SCRIPTPATH/certool.cfg
echo "Hostname = $PNID" >> $SCRIPTPATH/certool.cfg

echo "==================================" | tee -a $LOGFILE
echo "==================================" | tee -a $LOGFILE
echo ""
echo "Detected Root's certificate expiration date: $ROOTCERTDATE" | tee -a $LOGFILE
echo "Detected today's date: $TODAYSDATE" | tee -a $LOGFILE

echo "==================================" | tee -a $LOGFILE

flag=0
if [[ $TODAYSDATE > $ROOTCERTDATE ]];
then
    echo "IMPORTANT: Root certificate is expired, so it will be replaced" | tee -a $LOGFILE
    flag=1
	mkdir /certs && cd /certs
    cp $SCRIPTPATH/certool.cfg /certs/vmca.cfg
    /usr/lib/vmware-vmca/bin/certool --genselfcacert --outprivkey /certs/vmcacert.key  --outcert /certs/vmcacert.crt --config /certs/vmca.cfg
    /usr/lib/vmware-vmca/bin/certool --rootca --cert /certs/vmcacert.crt --privkey /certs/vmcacert.key
fi

echo "#" > $SCRIPTPATH/certool.cfg
echo "# Template file for a CSR request" >> $SCRIPTPATH/certool.cfg
echo "#" >> $SCRIPTPATH/certool.cfg
echo "# Country is needed and has to be 2 characters" >> $SCRIPTPATH/certool.cfg
echo "Country = DS" >> $SCRIPTPATH/certool.cfg
echo "Name = STS" >> $SCRIPTPATH/certool.cfg
echo "Organization = VMware" >> $SCRIPTPATH/certool.cfg
echo "OrgUnit = VMware" >> $SCRIPTPATH/certool.cfg
echo "State = VMware" >> $SCRIPTPATH/certool.cfg
echo "Locality = VMware" >> $SCRIPTPATH/certool.cfg
echo "IPAddress = $IPADDRESS" >> $SCRIPTPATH/certool.cfg
echo "Email = email@acme.com" >> $SCRIPTPATH/certool.cfg
echo "Hostname = $PNID" >> $SCRIPTPATH/certool.cfg



echo ""
echo "Exporting and generating STS certificate" | tee -a $LOGFILE
echo ""

cd $SCRIPTPATH

/usr/lib/vmware-vmca/bin/certool --server localhost --genkey --privkey=sts.key --pubkey=sts.pub
/usr/lib/vmware-vmca/bin/certool --gencert --cert=sts.cer --privkey=sts.key --config=$SCRIPTPATH/certool.cfg

openssl x509 -outform der -in sts.cer -out sts.der
CERTS=$(csplit -f root /var/lib/vmware/vmca/root.cer '/-----BEGIN CERTIFICATE-----/' '{*}' | wc -l)
openssl pkcs8 -topk8 -inform pem -outform der -in sts.key -out sts.key.der -nocrypt
i=1
until [ $i -eq $CERTS ]
do
	openssl x509 -outform der -in root0$i -out vmca0$i.der
	((i++))
done

echo ""
echo ""
if [ -n "$VMWARE_PASSWORD" ]
then
	$DOMAINPASSWORD = $VMWARE_PASSWORD
else
	read -s -p "Enter password for administrator@$DOMAIN: " DOMAINPASSWORD
fi


TENANTS=$(/opt/likewise/bin/ldapsearch -h localhost -p 389 -b "cn=$DOMAIN,cn=Tenants,cn=IdentityManager,cn=Services,$DOMAINCN" -D "cn=administrator,cn=users,$DOMAINCN" -w $DOMAINPASSWORD "(objectclass=vmwSTSTenantCredential)" | grep numEntries | awk '{print $3}')
echo ""
echo "Amount of tenant credentials: $TENANTS" | tee -a $LOGFILE
i=1
if [ ! -z $TENANTS ]  
then
	until [ $i -gt $TENANTS ]
	do
		echo "Exporting tenant and trustedcertchain $i to $SCRIPTPATH" | tee -a $LOGFILE
		echo ""
		ldapsearch -h localhost -D "cn=administrator,cn=users,$DOMAINCN" -w "$DOMAINPASSWORD" -b "cn=TenantCredential-$i,cn=$DOMAIN,cn=Tenants,cn=IdentityManager,cn=Services,$DOMAINCN" > $SCRIPTPATH/tenantcredential-$i.ldif
		ldapsearch -h localhost -D "cn=administrator,cn=users,$DOMAINCN" -w "$DOMAINPASSWORD" -b "cn=TrustedCertChain-$i,cn=TrustedCertificateChains,cn=$DOMAIN,cn=Tenants,cn=IdentityManager,cn=Services,$DOMAINCN" > $SCRIPTPATH/trustedcertchain-$i.ldif
		echo "Deleting tenant and trustedcertchain $i" | tee -a $LOGFILE
		ldapdelete -h localhost -D "cn=administrator,cn=users,$DOMAINCN" -w "$DOMAINPASSWORD" "cn=TenantCredential-$i,cn=$DOMAIN,cn=Tenants,cn=IdentityManager,cn=Services,$DOMAINCN" | tee -a $LOGFILE
		ldapdelete -h localhost -D "cn=administrator,cn=users,$DOMAINCN" -w "$DOMAINPASSWORD" "cn=TrustedCertChain-$i,cn=TrustedCertificateChains,cn=$DOMAIN,cn=Tenants,cn=IdentityManager,cn=Services,$DOMAINCN" | tee -a $LOGFILE
		((i++))
	done
fi
echo ""

i=1
echo "dn: cn=TenantCredential-1,cn=$DOMAIN,cn=Tenants,cn=IdentityManager,cn=Services,$DOMAINCN" > sso-sts.ldif
echo "changetype: add" >> sso-sts.ldif
echo "objectClass: vmwSTSTenantCredential" >> sso-sts.ldif
echo "objectClass: top" >> sso-sts.ldif
echo "cn: TenantCredential-1" >> sso-sts.ldif
echo "userCertificate:< file:sts.der" >> sso-sts.ldif
until [ $i -eq $CERTS ]
do
	echo "userCertificate:< file:vmca0$i.der" >> sso-sts.ldif
	((i++))
done
echo "vmwSTSPrivateKey:< file:sts.key.der" >> sso-sts.ldif
echo "" >> sso-sts.ldif
echo "dn: cn=TrustedCertChain-1,cn=TrustedCertificateChains,cn=$DOMAIN,cn=Tenants,cn=IdentityManager,cn=Services,$DOMAINCN" >> sso-sts.ldif
echo "changetype: add" >> sso-sts.ldif
echo "objectClass: vmwSTSTenantTrustedCertificateChain" >> sso-sts.ldif
echo "objectClass: top" >> sso-sts.ldif
echo "cn: TrustedCertChain-1" >> sso-sts.ldif
echo "userCertificate:< file:sts.der" >> sso-sts.ldif
i=1
until [ $i -eq $CERTS ]
do
	echo "userCertificate:< file:vmca0$i.der" >> sso-sts.ldif
	((i++))
done
echo ""
echo "Applying newly generated STS certificate to SSO domain" | tee -a $LOGFILE

/opt/likewise/bin/ldapmodify -x -h localhost -p 389 -D "cn=administrator,cn=users,$DOMAINCN" -w "$DOMAINPASSWORD" -f sso-sts.ldif | tee -a $LOGFILE
echo ""
echo "Replacement finished - Please restart services on all vCenters and PSCs in your SSO domain" | tee -a $LOGFILE
echo "==================================" | tee -a $LOGFILE
echo "IMPORTANT: In case you're using HLM (Hybrid Linked Mode) without a gateway, you would need to re-sync the certs from Cloud to On-Prem after following this procedure" | tee -a $LOGFILE
echo "==================================" | tee -a $LOGFILE
echo "==================================" | tee -a $LOGFILE
if [ $flag == 1 ]
then
	echo "Since your Root certificate was expired and was replaced, you will need to replace your MachineSSL and Solution User certificates" | tee -a $LOGFILE
	echo "You can do so following this KB: https://kb.vmware.com/s/article/2097936" | tee -a $LOGFILE
fi
