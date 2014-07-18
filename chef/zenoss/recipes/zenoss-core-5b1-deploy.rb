bash "Deploy Zenoss Core 5 beta 1" do
  user "root"
  code <<-EOH
green='\e[0;32m'
yellow='\e[0;33m'
endColor='\e[0m'
echo -e "${yellow}=== apt-get update ===${endColor}"
apt-get update
if [ $? -ne 0 ]; then
  echo 'Problem with apt-get update'
  exit 1
fi

echo -e "${yellow}=== ufw disable ===${endColor}"
ufw disable
if [ $? -ne 0 ]; then
  echo 'Problem with ufw disable'
  exit 1
fi

ulimitval=`ulimit -n`
echo "Current ulimit -n value: $ulimitval"
if [ $ulimitval -lt 1048575 ]; then
  echo -e "${yellow}=== setting /etc/security/limits.conf ===${endColor}"
  su -c 'cat <<EOF >> /etc/security/limits.conf
  * hard nofile 1048576
  * soft nofile 1048576
  root hard nofile 1048576
  root soft nofile 1048576
  EOF
  '
  if [ $? -ne 0 ]; then
    echo 'Problem with setting /etc/security/limits.conf'
    exit 1
  fi
  ulimitval=`ulimit -n`
  echo "Current ulimit -n value: $ulimitval"
fi
sudo su -

echo -e "${yellow}=== apt-get install -y curl nfs-kernel-server nfs-common net-tools wget ===${endColor}"
apt-get install -y curl nfs-kernel-server nfs-common net-tools wget
if [ $? -ne 0 ]; then
  echo 'Problem with apt-get install -y curl nfs-kernel-server nfs-common net-tools wget'
  exit 1
fi

echo -e "${yellow}=== installing docker ===${endColor}"
curl -sL https://get.docker.io/ubuntu/ | sh
if [ $? -ne 0 ]; then
  echo 'Problem with curl -sL https://get.docker.io/ubuntu/ | sh'
  exit 1
fi

echo -e "${yellow}=== downloading Zenoss Core 5b1 ===${endColor}"
STEM="http://sourceforge.net/projects/zenoss"
STEM="${STEM}/files/zenoss-beta/builds/europa-521"

dpkg -s docker-smuggle
if [ $? -ne 0 ]; then
  wget -N ${STEM}/docker-smuggle_2.24.2-1_amd64.deb
  if [ $? -ne 0 ]; then
    echo "Problem with wget -N ${STEM}/docker-smuggle_2.24.2-1_amd64.deb"
    exit 1
  fi
  dpkg -i docker-smuggle_*.deb
  if [ $? -ne 0 ]; then
    echo 'Problem with dpkg -i docker-smuggle_*.deb'
    exit 1
  fi
  apt-get install -f
  if [ $? -ne 0 ]; then
    echo 'Problem with apt-get install -f'
    exit 1
  fi
fi

dpkg -s serviced-zenoss-cores
if [ $? -ne 0 ]; then
  wget -N ${STEM}/serviced-zenoss-core_0.3.70+1.0.0b1-521~trusty_amd64.deb
  if [ $? -ne 0 ]; then
    echo "Problem with wget -N ${STEM}/serviced-zenoss-core_0.3.70+1.0.0b1-521~trusty_amd64.deb"
    exit 1
  fi
  dpkg -i serviced*.deb
  if [ $? -ne 0 ]; then
    echo 'Problem with dpkg -i serviced*.deb'
    exit 1
  fi
  apt-get install -f
  if [ $? -ne 0 ]; then
    echo 'Problem with apt-get install -f'
    exit 1
  fi
fi

echo -e "${yellow}=== downloading docker containers ===${endColor}"
docker pull quay.io/zenossinc/zenoss-core-testing:5.0.0b1_521
if [ $? -ne 0 ]; then
  echo 'Problem with docker pull quay.io/zenossinc/zenoss-core-testing:5.0.0b1_521'
  exit 1
fi
docker pull quay.io/zenossinc/opentsdb:v1
if [ $? -ne 0 ]; then
  echo 'Problem with docker pull quay.io/zenossinc/opentsdb:v1'
  exit 1
fi
docker pull quay.io/zenossinc/hbase:v1
if [ $? -ne 0 ]; then
  echo 'Problem with docker pull quay.io/zenossinc/hbase:v1'
  exit 1
fi

echo -e "${yellow}=== starting serviced ===${endColor}"
stop serviced
start serviced
if [ $? -ne 0 ]; then
  echo 'Problem with docker pull quay.io/zenossinc/hbase:v1'
  exit 1
fi

ip="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"

echo -e "${yellow}=== adding master host to default pool ===${endColor}"
serviced host add $ip:4979 default
if [ $? -ne 0 ]; then
  echo "Problem with serviced host add $ip:4979 default"
  exit 1
fi

id -u zenoss
if [ $? -ne 0 ]; then
  echo -e "${yellow}=== adding zenoss user ===${endColor}"
  useradd -m -U -s /bin/bash zenoss
  if [ $? -ne 0 ]; then
    echo "Problem with useradd -m -U -s /bin/bash zenoss"
    exit 1
  fi
  usermod -G docker -a zenoss
  usermod -G sudo -a zenoss
fi

grep SERVICED_NOREGISTRY /etc/init/serviced.conf
if [ $? -ne 0 ]; then
  echo -e "${yellow}=== disabling docker registry (single host config only) ===${endColor}"
  sed -i 's/\\/opt\\/serviced/\\/opt\\/serviced\\n\\texport SERVICED_NOREGISTRY=1/g' /etc/init/serviced.conf
  if [ $? -ne 0 ]; then
    echo "Problem with sed -i 's/\/opt\/serviced/\/opt\/serviced\n\texport SERVICED_NOREGISTRY=1/g' /etc/init/serviced.conf"
    exit 1
  fi   
fi

echo -e "${yellow}=== adding zenoss core template ===${endColor}"
TEMPLATEID=$(sudo serviced template add /opt/serviced/templates/zenoss-core-5.0.0b1_521.json);
echo -e "${yellow}=== deploying Zenoss services defined ===${endColor}"
serviced template deploy $TEMPLATEID default zenoss
if [ $? -ne 0 ]; then
  echo "Problem with serviced template deploy $TEMPLATEID default zenoss"
  exit 1
fi   

publicipv4="$(curl http://169.254.169.254/latest/meta-data/public-ipv4)"
echo -e "${green}Zenoss Core 5 beta 1 - installed${endColor}"
echo -e "${green}Set password for zenoss user: passwd zenoss${endColor}"
echo -e "${green}Go to Zenoss Service Control on https://$publicipv4/${endColor}"
echo -e "${green}Add line to your hosts file:${endColor}"
echo -e "${green}$publicipv4 zenosscc hbase.zenosscc opentsdb.zenosscc zenoss5x.zenosscc${endColor}"

# if your /var/log/upstart/serviced.log is always filled with connection refused lines:
# E0718 21:46:04.074986 00772 mux.go:119] got 172.31.44.0:22250 => 172.17.0.96:52045, could not dial to '172.31.44.0:49165' : dial tcp4 172.31.44.0:49165: connection refused
# it's probably docker issue https://github.com/dotcloud/docker/issues/2174
# try:
#su -c 'cat <<EOF >> /etc/sysctl.conf
#  net.ipv6.conf.all.forwarding=1
#  EOF
#  '

EOH
end
