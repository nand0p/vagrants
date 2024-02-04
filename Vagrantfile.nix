# NOTE: nixpkgs repo must be present in this dir

Vagrant.configure(2) do |config|
  config.vm.define "centos7" do |centos7|
    centos7.vm.synced_folder '.', '/vagrant', disabled: true 
    centos7.vm.synced_folder 'nixpkgs', '/home/vagrant/nixpkgs'
    config.vbguest.auto_update = true
    centos7.vm.box = "centos/7"
    centos7.vm.box_check_update = true
    centos7.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
      vb.cpus = "8"
    end
    centos7.vm.provision "shell", inline: <<-SHELL
      set -o errexit
      yum -y install perl-Digest-SHA git
      groupadd nixbld || true
      usermod -aG nixbld vagrant
      rm -rf /home/vagrant/nixpkgs/result
    SHELL
    centos7.vm.provision "shell", privileged: false, inline: <<-SHELL
      set -o errexit
      # NOTE: we may want to pin nix version explicitly going forward,
      #       but this is currently how nix is installed in prod/ci
      curl https://nixos.org/nix/install -o nix.install.sh
      bash nix.install.sh
      echo 'source ~/.nix-profile/etc/profile.d/nix.sh' >> /home/vagrant/.bashrc
      echo 'export NIXPKGS=/home/vagrant/nixpkgs' >> /home/vagrant/.bashrc
    SHELL
    centos7.vm.provision "shell", privileged: false, inline: <<-SHELL
      set -o errexit
      DATE=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
      echo $DATE
      cd nixpkgs

      BB_FULL=$(nix-build -A buildbot-full)
      echo "BB_FULL: $BB_FULL"
      $BB_FULL/bin/buildbot create-master /tmp/bb-full-$DATE
      mv -fv /tmp/bb-full-$DATE/master.cfg.sample /tmp/bb-full-$DATE/master.cfg
      nl /tmp/bb-full-$DATE/master.cfg
      $BB_FULL/bin/buildbot start /tmp/bb-full-$DATE
      curl localhost:8010
      cat /tmp/bb-full-$DATE/twistd.log

      BB_WORKER=$(nix-build -A buildbot-worker)
      echo $BB_WORKER
      $BB_WORKER/bin/buildbot-worker create-worker /tmp/bb-worker-$DATE localhost example-worker pass
      $BB_WORKER/bin/buildbot-worker start /tmp/bb-worker-$DATE
      cat /tmp/bb-worker-$DATE/twistd.log

      $BB_FULL/bin/buildbot stop /tmp/bb-full-$DATE
      cat /tmp/bb-full-$DATE/twistd.log

      BB_UI=$(nix-build -A buildbot-ui)
      echo "BB_UI: $BB_UI"
      $BB_UI/bin/buildbot create-master /tmp/bb-ui-$DATE
      mv -fv /tmp/bb-ui-$DATE/master.cfg.sample /tmp/bb-ui-$DATE/master.cfg
      sed -i -e '70,$d' /tmp/bb-ui-$DATE/master.cfg
      sed -i -e '71,$d' /tmp/bb-ui-$DATE/master.cfg
      echo "c['www'] = dict(port=8010)" >> /tmp/bb-ui-$DATE/master.cfg
      nl /tmp/bb-ui-$DATE/master.cfg
      $BB_UI/bin/buildbot start /tmp/bb-ui-$DATE
      curl localhost:8010
      $BB_UI/bin/buildbot stop /tmp/bb-ui-$DATE
      cat /tmp/bb-ui-$DATE/twistd.log

      BB=$(nix-build -A buildbot)
      echo "BB: $BB"
      $BB/bin/buildbot create-master /tmp/bb-$DATE
      mv -fv /tmp/bb-$DATE/master.cfg.sample /tmp/bb-$DATE/master.cfg
      sed -i -e '70,$d' /tmp/bb-$DATE/master.cfg
      sed -i -e '71,$d' /tmp/bb-$DATE/master.cfg
      nl /tmp/bb-$DATE/master.cfg
      $BB/bin/buildbot start /tmp/bb-$DATE
      $BB/bin/buildbot stop /tmp/bb-$DATE
      cat /tmp/bb-$DATE/twistd.log

    SHELL
  end
end
