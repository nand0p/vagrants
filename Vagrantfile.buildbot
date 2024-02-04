# Execute 'vagrant up' and 'vagrant ssh'.
# Requires VirtualBox is installed.

# Configure forks and branches.
TEST_FORK_BASE = 'buildbot'
TEST_BRANCH_BASE = 'master'
TEST_FORK_MIGRATION = 'nand0p'
TEST_BRANCH_MIGRATION = '3197_change_properties_to_text'
TEST_DB='postgres'
TEST_DB_MYSQL_VER='7'
TEST_DB_POSTGRES_VER='4'

# Enable developer tests here
TEST_BASE = 'false'
TEST_DB_SCHEMA_CHANGE_PROPERTIES = 'true'


Vagrant.configure(2) do |config|
  config.vm.define "buildbot" do |buildbot|
    buildbot.vm.box = "centos/7"
    buildbot.vm.box_check_update = true
    buildbot.vm.synced_folder '.', '/vagrant', disabled: true
    buildbot.vm.provider "virtualbox" do |vb|
      vb.gui = false
      #vb.memory = "2048"
      #vb.cpus = "8"
    end
    buildbot.vm.provision "shell", args: [TEST_DB_MYSQL_VER, TEST_DB_POSTGRES_VER], inline: <<-SHELL
      set -o errexit
      set -o nounset

      echo "installing deps:"
      yum -y group install development
      rpm -iv https://download.postgresql.org/pub/repos/yum/9.$2/redhat/rhel-7-x86_64/pgdg-centos9$2-9.$2-3.noarch.rpm || true
      rpm -iv https://dev.mysql.com/get/mysql5$1-community-release-el7-9.noarch.rpm || true
      yum -y install python-devel epel-release openssl-devel libffi-devel postgresql9$2-server postgresql9$2-devel mysql-server mysql-devel
      yum -y install python-pip
      export PATH=$PATH:/usr/pgsql-9.$2/bin
      echo "export PATH=$PATH:/usr/pgsql-9.$2/bin" | tee -a /home/vagrant/.bashrc
      pip install --upgrade pip virtualenv setuptools psycopg2
      /usr/pgsql-9.$2/bin/postgresql9$2-setup initdb || true
      sed -i 's/ident/md5/g' /var/lib/pgsql/9.$2/data/pg_hba.conf
      #echo "host all all 127.0.0.1/32 trust" | tee /var/lib/pgsql/9.$2/data/pg_hba.conf
      systemctl restart postgresql-9.$2.service
      systemctl enable postgresql-9.$2.service
      systemctl start mysqld
      systemctl enable mysqld

      echo "configure postgres:"
      cd /var/lib/pgsql
      sudo -u postgres psql -c "DROP DATABASE IF EXISTS bbdb;"
      sudo -u postgres psql -c "
        DROP ROLE IF EXISTS buildbot;
        CREATE USER buildbot WITH PASSWORD 'pass';
      "
      sudo -u postgres psql -c "CREATE DATABASE bbdb WITH OWNER buildbot;"
      sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE bbdb TO buildbot;"

      echo "configure mysql:"
      MYPASS=$(grep 'temporary password' /var/log/mysqld.log | rev | cut -d' ' -f1 | rev)
      echo -e "[client]\npassword=\\"$MYPASS\\"\nconnect-expired-password" | tee ~/.my.cnf
      echo -e "[mysqld]\nvalidate-password=off" | tee /etc/my.cnf
      systemctl stop mysqld
      sleep 1
      systemctl start mysqld
      mysql -u root -e "
        SET PASSWORD = PASSWORD(\\"$MYPASS\\");
        FLUSH PRIVILEGES;
        DROP DATABASE IF EXISTS bbdb;
        CREATE DATABASE IF NOT EXISTS bbdb;
        GRANT ALL PRIVILEGES ON bbdb.* TO buildbot@localhost identified by 'pass';
      "
    SHELL
    buildbot.vm.provision "shell", privileged: false, args: [TEST_FORK_BASE, TEST_BRANCH_BASE, TEST_DB], inline: <<-SHELL
      set -o errexit
      DATE=$(date +%s)

      echo "installing buildbot:"
      rm -rf /home/vagrant/buildbot
      git clone -b $2 https://github.com/$1/buildbot.git
      rm -rf /home/vagrant/.bb_venv
      virtualenv /home/vagrant/.bb_venv
      source /home/vagrant/.bb_venv/bin/activate
      pip install psycopg2 boto3 mock treq ramlfications lz4 moto txrequests autobahn mysql-python
      pip install -U http://ftp.buildbot.net/pub/latest/buildbot_www-1latest-py2-none-any.whl
      pip install -U http://ftp.buildbot.net/pub/latest/buildbot_codeparameter-1latest-py2-none-any.whl
      pip install -U http://ftp.buildbot.net/pub/latest/buildbot_console_view-1latest-py2-none-any.whl
      pip install -U http://ftp.buildbot.net/pub/latest/buildbot_waterfall_view-1latest-py2-none-any.whl
      cd /home/vagrant/buildbot/master
      python setup.py build
      python setup.py install
      cd /home/vagrant/buildbot/worker
      python setup.py build
      python setup.py install

      echo "configuring buildbot:"
      buildbot --verbose create-master /tmp/bb-$DATE
      mv -fv /tmp/bb-$DATE/master.cfg.sample /tmp/bb-$DATE/master.cfg
      echo "c['buildbotNetUsageData'] = None" | tee -a /tmp/bb-$DATE/master.cfg

      echo "configure database backend:"
      if [ "$3" == "postgres" ]; then
        sed -i 's|sqlite:///state.sqlite|postgresql://buildbot:pass@localhost/bbdb|' /tmp/bb-$DATE/master.cfg
      elif [ "$3" == "mysql" ]; then
        sed -i 's|sqlite:///state.sqlite|mysql+mysqldb://buildbot:pass@localhost/bbdb|' /tmp/bb-$DATE/master.cfg
      fi
      grep -v '#' /tmp/bb-$DATE/master.cfg | grep -v -e '^$' | nl

      echo "upgrading database:"
      buildbot --verbose upgrade-master /tmp/bb-$DATE
      tail -10 /tmp/bb-$DATE/twistd.log | nl

      echo "source ~/.bb_venv/bin/activate" | tee -a ~/.bashrc
    SHELL
    if TEST_BASE == 'true'
      buildbot.vm.provision "shell", privileged: false, inline: <<-SHELL
        echo "up and down buildbot:"
        buildbot --verbose start /tmp/bb-$DATE
        curl localhost:8010
        tail -20 /tmp/bb-$DATE/twistd.log | nl
        buildbot-worker --verbose create-worker /tmp/bb-worker-$DATE localhost example-worker pass
        buildbot-worker --verbose start /tmp/bb-worker-$DATE
        tail -20 /tmp/bb-worker-$DATE/twistd.log | nl
        buildbot-worker --verbose stop /tmp/bb-worker-$DATE
        tail -5 /tmp/bb-worker-$DATE/twistd.log | nl
        buildbot --verbose stop /tmp/bb-$DATE
        tail -5 /tmp/bb-$DATE/twistd.log | nl

        echo "running tests:"
        cd /home/vagrant/buildbot
        git status
        trial buildbot.test
      SHELL
    end
    if TEST_DB_SCHEMA_CHANGE_PROPERTIES == 'true'
      buildbot.vm.provision "shell", privileged: false, args: [TEST_FORK_MIGRATION, TEST_BRANCH_MIGRATION, TEST_DB], inline: <<-SHELL
        set -o errexit
        DATE=$(date +%s)

        echo "prepare migration test:"
        buildbot --verbose create-master /tmp/bb-mig-$DATE
        mv -fv /tmp/bb-mig-$DATE/master.cfg.sample /tmp/bb-mig-$DATE/master.cfg
        echo "c['buildbotNetUsageData'] = None" | tee -a /tmp/bb-mig-$DATE/master.cfg
        if [ "$3" == "postgres" ]; then
          sed -i 's|sqlite:///state.sqlite|postgresql://buildbot:pass@localhost/bbdb|' /tmp/bb-mig-$DATE/master.cfg
        elif [ "$3" == "mysql" ]; then
          sed -i 's|sqlite:///state.sqlite|mysql://buildbot:pass@localhost/bbdb|' /tmp/bb-mig-$DATE/master.cfg
        fi
        grep -v '#' /tmp/bb-mig-$DATE/master.cfg | grep -v -e '^$' | nl
        buildbot --verbose start /tmp/bb-mig-$DATE
        tail -20 /tmp/bb-mig-$DATE/twistd.log | nl
        buildbot --verbose stop /tmp/bb-mig-$DATE
        tail -5 /tmp/bb-mig-$DATE/twistd.log | nl

        echo "verify db schema:"
        if [ "$3" == "postgres" ]; then
          cd / && sudo -u postgres psql -d bbdb -c "
            SELECT column_name, data_type, character_maximum_length
            FROM information_schema.columns
            WHERE table_name = 'change_properties';
          "
        elif [ "$3" == "mysql" ]; then
          sudo mysql -e 'describe bbdb.change_properties'
        else
          sqlite3 -line /tmp/bb-mig-$DATE/state.sqlite ".schema change_properties"
        fi

        echo "upgrade code and database:"
        cd /home/vagrant/buildbot/master
        git remote add nando https://github.com/$1/buildbot.git
        git fetch --all
        git checkout $2
        python setup.py build
        python setup.py install
        buildbot --verbose upgrade-master /tmp/bb-mig-$DATE

        echo "test db schema:"
        if [ "$3" == "postgres" ]; then
          cd / && sudo -u postgres psql -d bbdb -c "
            SELECT column_name, data_type, character_maximum_length
            FROM information_schema.columns
            WHERE table_name = 'change_properties';
          "
        elif [ "$3" == "mysql" ]; then
          sudo mysql -e 'describe bbdb.change_properties'
          sudo mysqld --version
        else
          sqlite3 -line /tmp/bb-mig-$DATE/state.sqlite ".schema change_properties"
        fi

        echo "run tests:"
        cd /home/vagrant/buildbot
        git status
        time trial buildbot.test | grep -A 1 048
      SHELL
    end
    buildbot.vm.provision "shell", privileged: false, inline: <<-SHELL
        echo "all g00d."
    SHELL
  end
end
