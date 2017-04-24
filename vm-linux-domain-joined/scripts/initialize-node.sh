#!/bin/bash
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# 
# See the License for the specific language governing permissions and
# limitations under the License.

ADDNS=$1
PDC=$2
BDC=$3
PDCIP=$4
BDCIP=$5
ADMINUSER=$6
DOMAINADMINUSER=$7
DOMAINADMINPWD=$8

replace_ad_params() {
    target=${1}
    shortdomain=`echo ${ADDNS} | sed 's/\.[^.]*$//'`
    sed -i "s/REPLACEADDOMAIN/${ADDNS}/g" ${target}
    sed -i "s/REPLACEUPADDOMAIN/${ADDNS^^}/g" ${target}
    sed -i "s/REPLACESHORTADDOMAIN/${shortdomain}/g" ${target}
    sed -i "s/REPLACEPDC/${PDC}/g" ${target}
    sed -i "s/REPLACEBDC/${BDC}/g" ${target}
    sed -i "s/REPLACEIPPDC/${PDCIP}/g" ${target}
    sed -i "s/REPLACEIPBDC/${BDCIP}/g" ${target}
}

# Disable the need for a tty when running sudo and allow passwordless sudo for the admin user
sed -i '/Defaults[[:space:]]\+!*requiretty/s/^/#/' /etc/sudoers
echo "$ADMINUSER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

myhostname=`hostname`
fqdnstring=`python -c "import socket; print socket.getfqdn('$myhostname')"`
sed -i "s/.*HOSTNAME.*/HOSTNAME=${fqdnstring}/g" /etc/sysconfig/network
/etc/init.d/network restart

yum install -y ntp
yum -y remove samba-client
yum -y remove samba-common
yum -y install sssd
yum -y install sssd-client
yum -y install krb5-workstation
yum -y install samba4
yum -y install openldap-clients
yum -y install policycoreutils-python

cp -f resolv.conf /etc/resolv.conf
replace_ad_params /etc/resolv.conf
cp -f krb5.conf /etc/krb5.conf
replace_ad_params /etc/krb5.conf
cp -f smb.conf /etc/samba/smb.conf
replace_ad_params /etc/samba/smb.conf
cp -f sssd.conf /etc/sssd/sssd.conf
replace_ad_params /etc/sssd/sssd.conf
cp -f ntp.conf /etc/ntp.conf
replace_ad_params /etc/ntp.conf

cat > /etc/dhclient-enter-hooks << EOF
#!/bin/sh
make_resolv_conf() {
echo "do not change resolv.conf"
}
EOF
chmod a+x /etc/dhclient-enter-hooks
chmod 600 /etc/sssd/sssd.conf
service ntpd start
chkconfig ntpd on
service smb start
chkconfig smb on
authconfig --enablesssd --enablemkhomedir --enablesssdauth --update
service sssd start
chkconfig sssd on
