if node['kernel']['machine'] == 'x86_64'

  # detect public IP (AWS/HP Cloud)
  publicipv4=`curl -s http://169.254.169.254/latest/meta-data/public-ipv4`
  ip_regex = /^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$/
  if !( ip_regex =~ publicipv4)
    publicipv4=`ifconfig | grep -A 1 'eth0 ' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1`
  end
  publicipv4 = publicipv4.strip

  bash "Update /etc/hosts (public IP, special requirement for AWS/HP Cloud/...)" do
    user "root"
    code <<-EOH
    hostname=$(uname -n)
    privateipv4="$(ifconfig | grep -A 1 'eth0 ' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
    grep "$privateipv4 $hostname" /etc/hosts
    if [ $? -ne 0 ]; then
      echo "echo \"$privateipv4 $hostname\" >> /etc/hosts"
      echo "$privateipv4 $hostname" >> /etc/hosts
    fi
    EOH
  end

  bash "Install docker" do
    user "root"
    code <<-EOH
    echo 'wget -O - http://get.docker.io | sh'
    wget -O - http://get.docker.io | sh
    EOH
  end

  bash "Add the current user account to the dockergroup" do
    user "root"
    code <<-EOH
    echo 'usermod -aG docker $USER'
    usermod -aG docker $USER
    EOH
  end

  bash "Install the Zenoss OpenPGP public key" do
    user "root"
    code <<-EOH
    echo 'apt-key adv --keyserver keys.gnupg.net --recv-keys AA5A1AD7'
    apt-key adv --keyserver keys.gnupg.net --recv-keys AA5A1AD7
    EOH
  end

  bash "Add the Zenoss repository to the list of repositories" do
    user "root"
    code <<-EOH
    echo "sh -c 'echo \"deb [ arch=amd64 ] http://get.zenoss.io/apt/ubuntu trusty universe\" > /etc/apt/sources.list.d/zenoss.list'"
    sh -c 'echo "deb [ arch=amd64 ] http://get.zenoss.io/apt/ubuntu trusty universe" > /etc/apt/sources.list.d/zenoss.list'
    EOH
  end

  bash "Update the Ubuntu repository database" do
    user "root"
    code <<-EOH
    echo 'apt-get update'
    apt-get update
    EOH
  end

  bash "Install the Zenoss Core service template" do
    user "root"
    code <<-EOH
    echo 'apt-get install -y zenoss-core-service'
    apt-get install -y zenoss-core-service
    EOH
  end
  
  bash "Start the Zenoss Control Center service" do
    user "root"
    code <<-EOH
    echo 'stop serviced'
    stop serviced
    echo 'sleep 30'
    sleep 30
    echo 'start serviced'
    start serviced
    EOH
  end  

  bash "Install the NTP package and start ntpd (for multi-host deployment)" do
    user "root"
    code <<-EOH
    echo 'apt-get install -y ntp'
    apt-get install -y ntp
    EOH
  end
  
  # TODO command is not executed correctly
  #bash "Configure the Zenoss Control Center daemon to restart upon reboot" do
  #  user "root"
  #  code <<-EOH
  #  S1='start on (filesystem and started docker and '
  #  S2='(started network-interface or started '
  #  S3='network-manager or started networking) )'
  #  NEW="\n${S1}${S2}${S3}"
  #  grep "$S1$S2$S3" /etc/init/serviced.conf
  #  if [ $? -ne 0 ]; then
  #    echo "sed -i -e 's|^\\(start on.*\\)$|#\\1|' -e '/^#start on/ s|$|'\"${NEW}\"'|' /etc/init/serviced.conf"
  #    sed -i -e 's|^\(start on.*\)$|#\1|' -e '/^#start on/ s|\\$|'"\\${NEW}"'|' /etc/init/serviced.conf         
  #  fi
  #  EOH
  #end

  bash "Create user zenoss and add zenoss to docker and sudo group" do
    user "root"                                              
    code <<-EOH
    id -u zenoss
    if [ $? -ne 0 ]; then
      echo 'adduser --gecos ",,," --disabled-password zenoss'
      adduser --gecos ",,," --disabled-password zenoss
      echo 'usermod -aG docker zenoss'
      usermod -aG docker zenoss
      echo 'usermod -aG sudo zenoss'
      usermod -aG sudo zenoss
    fi
    EOH
  end
  
  bash "Add hosts to the default resource pool" do
    user "root"
    code <<-EOH
    echo "serviced host list 2>&1"
    test=$(serviced host list 2>&1)
    if [ "$test" = "no hosts found" ]; then
      echo "ifconfig | grep -A 1 'eth0 ' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1"
      privateipv4=$(ifconfig | grep -A 1 'eth0 ' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)
      echo "serviced host add $privateipv4:4979 default"
      serviced host add $privateipv4:4979 default
      if [ $? -ne 0 ]; then
        echo "Problem with command: serviced host add $privateipv4:4979 default"
        exit 1
      fi
    else
      echo "echo \"$test\" | grep $(uname -n) | wc -l"
      test2=$(echo "$test" | grep $(uname -n) | wc -l)
      if [ "$test2" = "1" ]; then
        echo "Skipping - host is deployed already"
      else 
        echo "Skipping adding a host - check output from test: $test"
        exit 1
      fi  
    fi    
    EOH
  end
  
  bash "Deploy an application (the deployment step can take 10-20 minutes)" do
    user "root"
    code <<-EOH
    echo "serviced template list 2>&1 | grep 'Zenoss.core' | awk '{print \$1}'"
    TEMPLATEID=$(serviced template list 2>&1 | grep 'Zenoss.core' | awk '{print $1}')
    echo 'serviced service list 2>/dev/null | wc -l'
    services=$(serviced service list 2>/dev/null | wc -l)                      
    if [ "$TEMPLATEID" = "f8ae57f5d9df9141f1e3c435a14c466b" ] && [ "$services" = "0" ]; then
      echo "serviced template deploy $TEMPLATEID default zenoss"
      serviced template deploy $TEMPLATEID default zenoss
      if [ $? -ne 0 ]; then
        echo "Problem with command: serviced template deploy $TEMPLATEID default zenoss"
        exit 1
      fi
    else
      if [ "$services" -gt "0" ]; then
        echo -e "Skipping - some services are deployed, check: serviced service list"
      else
        echo -e "Skipping deloying an application - check output from template test: $TEMPLATEID"
        exit 1
      fi
    fi
    EOH
  end   

  log "Zenoss Core beta 2 install completed successfully!" do
    message "Set password for zenoss user: passwd zenoss\n \
    Please visit Control Center https://#{publicipv4}/ in your favorite web browser to complete setup, log in with zenoss user\n \
    Add following line to your hosts file:\n \
    #{publicipv4} #{node['hostname']} hbase.#{node['hostname']} opentsdb.#{node['hostname']} zenoss5x.#{node['hostname']}\n \
    Run following command manually:\n \
    S1='start on (filesystem and started docker and '\n \
    S2='(started network-interface or started '\n \
    S3='network-manager or started networking) )'\n \
    NEW=\"\\n${S1}${S2}${S3}\"\n \
    sudo sed -i -e 's|^\(start on.*\)$|#\1|' \\ \n \
    -e '/^#start on/ s|$|'\"\${NEW}\"'|' \\ \n \
    /etc/init/serviced.conf\n"
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
