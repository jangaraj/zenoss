#!/bin/bash
######################################################
#
# A simple script to auto-install Zenoss Core 5 beta 2
# Manual install guide: 
# http://beta.zenoss.io/Core-5-Beta-2/Documentation/Zenoss_Core_Beta_Installation_Guide_r5.0.0b2_d99.14.241-DRAFT.pdf
#
# This script should be run on a base install of
# Ubuntu 14. Cloud (AWS/HP Cloud) ready.
#
######################################################

green='\e[0;32m'
yellow='\e[0;33m'
red='\e[0;31m'
endColor='\e[0m'

echo -e "${yellow}Root permission check${endColor}"
if [ "$EUID" -ne 0 ]; then
  echo -e "${red}Please run as root or use sudo${endColor}"
  exit 1
fi

echo -e "${yellow}Architecture check${endColor}"
arch=$(uname -m)
if [ ! "$arch" = "x86_64" ]; then
	echo -e "${red}Not supported architecture $arch. Architecture x86_64 only is supported.${endColor}"
    exit 1
fi

echo -e "${yellow}Update /etc/hosts (special requirement for AWS/HP Cloud/...)${endColor}"
hostname=$(uname -n)
privateipv4="$(ifconfig | grep -A 1 'eth0 ' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
publicipv4=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 | tr '\n' ' ')
if [[ ! $publicipv4 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    publicipv4=$privateipv4
fi
echo grep "\"$privateipv4 $hostname\" /etc/hosts"
grep "$privateipv4 $hostname" /etc/hosts
if [ $? -ne 0 ]; then
  echo "echo \"$privateipv4 $hostname\" >> /etc/hosts"
  echo "$privateipv4 $hostname" >> /etc/hosts
fi

echo -e "${yellow}Install docker${endColor}"
echo 'wget -O - http://get.docker.io | sh'
wget -O - http://get.docker.io | sh

echo -e "${yellow}Add the current user account to the dockergroup${endColor}"
echo 'usermod -aG docker $USER'
usermod -aG docker $USER

echo -e "${yellow}Install the Zenoss OpenPGP public key${endColor}"
echo 'apt-key adv --keyserver keys.gnupg.net --recv-keys AA5A1AD7'
apt-key adv --keyserver keys.gnupg.net --recv-keys AA5A1AD7

echo -e "${yellow}Add the Zenoss repository to the list of repositories${endColor}"
echo "sh -c 'echo 'deb [ arch=amd64 ] http://get.zenoss.io/apt/ubuntu trusty universe' > /etc/apt/sources.list.d/zenoss.list"
sh -c 'echo "deb [ arch=amd64 ] http://get.zenoss.io/apt/ubuntu trusty universe" > /etc/apt/sources.list.d/zenoss.list'

echo -e "${yellow}Update the Ubuntu repository database${endColor}"
echo 'apt-get update'
apt-get update

echo -e "${yellow}Install the Zenoss Core service template${endColor}"
echo 'apt-get install -y zenoss-core-service'
apt-get install -y zenoss-core-service

echo -e "${yellow}Start the Zenoss Control Center service${endColor}"
echo 'stop serviced'
stop serviced
# TODO sometimes serviced is not able start, because previouse instance is still up
# workaround: sleep 30
# I0907 13:42:28.823990 15689 api.go:86] StartServer: [] (0)
# F0907 13:42:28.827193 15689 daemon.go:121] Could not bind to port listen tcp :4979: bind: address already in use. Is another instance running
# Sun Sep  7 13:42:28 UTC 2014: waiting for serviced to stop
# Sun Sep  7 13:42:28 UTC 2014: serviced is now stopped - done with post-stop
echo 'sleep 30'
sleep 30
echo 'start serviced'
start serviced

echo -e "${yellow}Install the NTP package and start ntpd (for multi-host deployment)${endColor}"
echo 'apt-get install -y ntp'
apt-get install -y ntp

echo -e "${yellow}Configure the Zenoss Control Center daemon to restart upon reboot${endColor}"
S1='start on (filesystem and started docker and '
S2='(started network-interface or started '
S3='network-manager or started networking) )'
NEW="\n${S1}${S2}${S3}"
echo "grep \"$S1$S2$S3\" /etc/init/serviced.conf"
grep "$S1$S2$S3" /etc/init/serviced.conf
if [ $? -ne 0 ]; then
  echo "sed -i -e 's|^\(start on.*\)$|#\1|' -e '/^#start on/ s|$|'\"${NEW}\"'|' /etc/init/serviced.conf"
  sed -i -e 's|^\(start on.*\)$|#\1|' -e '/^#start on/ s|$|'"${NEW}"'|' /etc/init/serviced.conf
fi

echo -e "${yellow}Create user zenoss and add zenoss to docker and sudo group${endColor}"
echo 'id -u zenoss'
id -u zenoss
if [ $? -ne 0 ]; then
  echo 'adduser --gecos ",,," --disabled-password zenoss'
  adduser --gecos ",,," --disabled-password zenoss
  echo 'usermod -aG docker zenoss'
  usermod -aG docker zenoss
  echo 'usermod -aG sudo zenoss'
  usermod -aG sudo zenoss
fi
  
echo -e "${yellow}Add hosts to the default resource pool${endColor}"
echo "serviced host list 2>&1"
test=$(serviced host list 2>&1)
if [ "$test" = "no hosts found" ]; then
  echo "serviced host add $privateipv4:4979 default"
  serviced host add $privateipv4:4979 default
  if [ $? -ne 0 ]; then
    echo -e "${red}Problem with command: serviced host add $privateipv4:4979 default${endColor}"
    exit 1
  fi
else
  echo "echo \"$test\" | grep \$(uname -n) | wc -l"
  test2=$(echo "$test" | grep $(uname -n) | wc -l)
  if [ "$test2" = "1" ]; then
    echo -e "${yellow}Skipping - host is deployed already${endColor}"
  else 
    echo -e "${red}Skipping adding a host - check output from test: $test${endColor}"
    exit 1
  fi  
fi
  
echo -e "${yellow}Deploy an application (the deployment step can take 10-20 minutes)${endColor}"
echo "serviced template list 2>&1 | grep 'Zenoss.core' | awk '{print \$1}'"
TEMPLATEID=$(serviced template list 2>&1 | grep 'Zenoss.core' | awk '{print $1}')
echo 'serviced service list 2>/dev/null | wc -l'
services=$(serviced service list 2>/dev/null | wc -l)                      
if [ "$TEMPLATEID" = "f8ae57f5d9df9141f1e3c435a14c466b" ] && [ "$services" = "0" ]; then
  echo "serviced template deploy $TEMPLATEID default zenoss"
  serviced template deploy $TEMPLATEID default zenoss
  if [ $? -ne 0 ]; then
    echo -e "${red}Problem with command: serviced template deploy $TEMPLATEID default zenoss${endColor}"
    exit 1
  fi
else
  if [ "$services" -gt "0" ]; then
    echo -e "${yellow}Skipping - some services are deployed, check: serviced service list${endColor}"
  else
    echo -e "${red}Skipping deloying an application - check output from template test: $TEMPLATEID${endColor}"
    exit 1
  fi
fi   

echo -e "${green}Zenoss Core beta 2 install completed successfully!${endColor}"
echo -e "${green}Set password for zenoss user: passwd zenoss${endColor}"
echo -e "${green}Please visit Control Center https://$publicipv4/ in your favorite web browser to complete setup, log in with zenoss user${endColor}"
echo -e "${green}Add following line to your hosts file:${endColor}"
echo -e "${green}$publicipv4 $hostname hbase.$hostname opentsdb.$hostname zenoss5x.$hostname${endColor}"
