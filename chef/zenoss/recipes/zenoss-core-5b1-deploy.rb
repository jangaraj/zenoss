bash "Deploy Zenoss Core 5 beta 1" do
  user "root"
  code <<-EOH
echo '=== apt-get update ==='
apt-get update
if [ $? -ne 0 ]; then
  echo 'Problem with apt-get update'
  exit 1
fi

echo '=== ufw disable ==='
ufw disable
if [ $? -ne 0 ]; then
  echo 'Problem with ufw disable'
  exit 1
fi

ulimitval=`ulimit -n`
echo "Current ulimit -n value: $ulimitval"
if [ $ulimitval -lt 1048575 ]; then
echo '=== setting /etc/security/limits.conf ==='
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
fi
sudo su -

echo '=== apt-get install -y curl nfs-kernel-server nfs-common net-tools wget ==='
apt-get install -y curl nfs-kernel-server nfs-common net-tools wget
if [ $? -ne 0 ]; then
  echo 'Problem with apt-get install -y curl nfs-kernel-server nfs-common net-tools wget'
  exit 1
fi

echo '=== docker installation ==='
curl -sL https://get.docker.io/ubuntu/ | sh
if [ $? -ne 0 ]; then
  echo 'Problem with curl -sL https://get.docker.io/ubuntu/ | sh'
  exit 1
fi

echo '=== downloading Zenoss Core 5b1 from sourceforge ==='
STEM="http://sourceforge.net/projects/zenoss"
STEM="${STEM}/files/zenoss-beta/builds/europa-521"
wget --progress=dot ${STEM}/docker-smuggle_2.24.2-1_amd64.deb
if [ $? -ne 0 ]; then
  echo "Problem with wget ${STEM}/docker-smuggle_2.24.2-1_amd64.deb"
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
usermod -G docke
fi
wget --progress=dot ${STEM}/serviced-zenoss-core_0.3.70+1.0.0b1-521~trusty_amd64.deb
if [ $? -ne 0 ]; then
  echo "Problem with wget ${STEM}/serviced-zenoss-core_0.3.70+1.0.0b1-521~trusty_amd64.deb"
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

echo '=== downloading docker containers ==='
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

echo '===  start serviced ==='
start serviced
if [ $? -ne 0 ]; then
  echo 'Problem with docker pull quay.io/zenossinc/hbase:v1'
  exit 1
fi

ip="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"

echo '=== add master host to default pool ==='
serviced host add $ip:4979 default
if [ $? -ne 0 ]; then
  echo "Problem with serviced host add $ip:4979 default"
  exit 1
fi

id -u zenoss
if [ $? -ne 0 ]; then
  echo '=== zenoss user ==='
  pass=$(perl -e 'print crypt($ARGV[0], "zenoss")' "zenoss")
  adduser -m -p $pass zenoss
  if [ $? -ne 0 ]; then
    echo "Problem with adduser -m -p $pass zenoss"
    exit 1
  fi
  usermod -G docker -a zenoss
  usermod -G sudo -a zenoss
fi

TEMPLATEID=$(sudo serviced template add /opt/serviced/templates/zenoss-core-5.0.0b1_521.json);

publicipv4="(curl http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Zenoss Core 5 beta 1 - installed"
echo "Go to Zenoss Service Control on https://$publicipv4/"
