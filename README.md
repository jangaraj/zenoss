zenoss
======
chef/
- chef recipes are "evolution" of autodeploy scripts
zenoss-core-5b2-deploy.rb provide deployment of Zenoss Core beta 2, install guide: http://beta.zenoss.io/Core-5-Beta-2/Documentation/Zenoss_Core_Beta_Installation_Guide_r5.0.0b2_d99.14.241-DRAFT.pdf
Recipe includes:
- install Zenoss Control Center
- install Zenoss Core
- enabling client access

It should works also with AWS EC2 by default. Tested only with HP Cloud at the moment. 
```
root@zenoss5b2:~# find chef
chef
chef/solo.rb
chef/zenoss-core-5b2-deploy.json
chef/cookbooks
chef/cookbooks/zenoss
chef/cookbooks/zenoss/recipes
chef/cookbooks/zenoss/recipes/zenoss-core-5b2-deploy.rb
root@zenoss5b2:~# cat chef/solo.rb

file_cache_path "/root/chef"
cookbook_path "/root/chef/cookbooks"
json_attribs "/root/chef/zenoss-core-5b2-deploy.json"

root@zenoss5b2:~# chef-solo -c ~/chef/solo.rb -l debug
[2014-09-05T23:37:35+00:00] INFO: Forking chef instance to converge...
[2014-09-05T23:37:35+00:00] DEBUG: Fork successful. Waiting for new chef pid: 2370
[2014-09-05T23:37:35+00:00] DEBUG: Forked instance now converging
Starting Chef Client, version 11.8.2
[2014-09-05T23:37:35+00:00] INFO: *** Chef 11.8.2 ***
[2014-09-05T23:37:35+00:00] INFO: Chef-client pid: 2370
[2014-09-05T23:37:35+00:00] DEBUG: Building node object for zenoss5b2

...

  * log[Zenoss Core beta 2 installed] action write[2014-09-05T23:42:38+00:00] INFO: Processing log[Zenoss Core beta 2 installed] action write (zenoss::zenoss-core-5b2-deploy line 120)
[2014-09-05T23:42:38+00:00] DEBUG: Platform ubuntu version 14.04 found
[2014-09-05T23:42:38+00:00] WARN: Set password for zenoss user: passwd zenoss
     Go to Zenoss Service Control on public IP https://xxx.xxx.xxx.xxx/ and log in with zenoss user
     Add line to your hosts file with public IP:
     xxx.xxx.xxx.xxx zenoss5b2 hbase.zenoss5b2 opentsdb.zenoss5b2 zenoss5x.zenoss5b2

[2014-09-05T23:42:38+00:00] INFO: Chef Run complete in 302.372614304 seconds
[2014-09-05T23:42:38+00:00] INFO: Running report handlers
[2014-09-05T23:42:38+00:00] INFO: Report handlers complete
Chef Client finished, 14 resources updated
[2014-09-05T23:42:38+00:00] DEBUG: Forked instance successfully reaped (pid: 2370)
[2014-09-05T23:42:38+00:00] DEBUG: Exiting
```

