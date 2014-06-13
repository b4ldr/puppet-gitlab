#!/bin/bash
apt-get update 

sudo apt-get install -y python-software-properties
cd /tmp
wget http://apt.puppetlabs.com/puppetlabs-release-precise.deb
sudo dpkg -i puppetlabs-release-precise.deb
apt-get update 
apt-get install -y puppet-common
apt-get install -y git
git clone https://github.com/b4ldr/puppet-nginx /etc/puppet/modules/nginx
git clone https://github.com/puppetlabs/puppetlabs-vcsrepo /etc/puppet/modules/vcsrepo

echo "127.0.0.1 localhost.localdomain localhost
127.0.0.1 gitlab.localdomain gitlab" > /etc/hosts
echo "gitlab" > /etc/hostname

puppet module install puppetlabs-apt
puppet module install puppetlabs-mysql
puppet module install puppetlabs-ruby
puppet module install puppetlabs-concat
#puppet module install puppetlabs-vcsrepo
puppet module install example42-postfix
#puppet module install maestrodev-wget
