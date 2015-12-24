# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.define "centos7" do |centos7|
    centos7.vm.box = "centos/7"
    centos7.vm.box_check_update = true
    centos7.vm.network "forwarded_port", guest: 80, host: 22334
    centos7.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "512"
    end
    centos7.vm.provision "shell", inline: <<-SHELL
     sudo yum update
     sudo yum install -y epel-release
     sudo yum install -y nginx
     sudo service nginx start
    SHELL
  end
end
