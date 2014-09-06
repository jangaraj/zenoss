if node['kernel']['machine'] == 'x86_64'

  # detect public IP (AWS/HP Cloud)
  publicipv4=`curl -s http://169.254.169.254/latest/meta-data/public-ipv4`
  ip_regex = /^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$/
  if !( ip_regex =~ publicipv4)
    publicipv4=`ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1`
  end
  publicipv4 = publicipv4.strip

  bash "Update /etc/hosts (public IP, special requirement for AWS/HP Cloud/...)" do
    user "root"
    code <<-EOH
    hostname=$(uname -n)
    privateipv4="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
    grep "$privateipv4 $hostname" /etc/hosts
    if [ $? -ne 0 ]; then
      echo "$privateipv4 $hostname" >> /etc/hosts
    fi
    EOH
  end

  bash "Install docker" do
    user "root"
    code <<-EOH
    wget -O - http://get.docker.io | sh
    EOH
  end

  bash "Add the root user account to the dockergroup" do
    user "root"
    code <<-EOH
    usermod -aG docker $USER
    EOH
  end

  bash "Install the Zenoss OpenPGP public key" do
    user "root"
    code <<-EOH
    apt-key adv --keyserver keys.gnupg.net --recv-keys AA5A1AD7
    EOH
  end

  bash "Add the Zenossrepository to the list of repositories" do
    user "root"
    code <<-EOH
    sh -c 'echo "deb [ arch=amd64 ] http://get.zenoss.io/apt/ubuntu trusty universe" > /etc/apt/sources.list.d/zenoss.list'
    EOH
  end

  bash "Update the Ubuntu repository database" do
    user "root"
    code <<-EOH
    apt-get update
    EOH
  end

  bash "Update the Ubuntu repository database" do
    user "root"
    code <<-EOH
    apt-get update
    EOH
  end

  bash "Install the NTP package and start ntpd (for multi-host deployment)" do
    user "root"
    code <<-EOH
    apt-get install -y ntp
    EOH
  end

  bash "Install the Zenoss Coreservice template" do
    user "root"
    code <<-EOH
    apt-get install -y zenoss-core-service
    EOH
  end

  bash "Configure the Zenoss Control Center daemon to restart upon reboot" do
    user "root"
    code <<-EOH
    S1='start on (filesystem and started docker and '
    S2='(started network-interface or started '
    S3='network-manager or started networking) )'
    NEW="\n${S1}${S2}${S3}"
    grep "$NEW" /etc/init/serviced.conf
    if [ $? -ne 0 ]; then
      sed -i -e 's|^\(start on.*\)$|#\1|' -e '/^#start on/ s|$|'"${NEW}"'|' /etc/init/serviced.conf
    fi
    EOH
  end

  bash "Start the Zenoss Control Center service" do
    user "root"
    code <<-EOH
    stop serviced
    start serviced
    EOH
  end

  bash "Create user zenoss and add zenoss to docker and sudo group" do
    user "root"
    code <<-EOH
    id -u zenoss
    if [ $? -ne 0 ]; then
      adduser zenoss
      usermod -aG docker zenoss
      usermod -aG sudo zenoss
    fi
    EOH
  end

  log "Zenoss Core beta 2 installed" do
    message "Set password for zenoss user: passwd zenoss\n \
    Go to Zenoss Service Control on public IP https://#{publicipv4}/ and log in with zenoss user\n \
    Add line to your hosts file with public IP:\n \
    #{publicipv4} #{node['hostname']} hbase.#{node['hostname']} opentsdb.#{node['hostname']} zenoss5x.#{node['hostname']}"
    level :warn
  end

  # https://supermarket.getchef.com/cookbooks/apt
  #apt_repository "zenoss" do
  #  uri         "http://get.zenoss.io/apt/ubuntu"
  #  distribution "trusty"
  #  components   ["universe"]
  #  keyserver   "keys.gnupg.net"
  #  key         "AA5A1AD7"
  #end

else
  log "Not supported architecture #{node['kernel']['machine']}! Architecture x86_64 only is supported." do
    level :error
  end
end
