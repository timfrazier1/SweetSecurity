
cd /home/pi

echo "Installing Pre-Requisites..."
#First need to make sure all repos are up to date
sudo apt-get update
sudo apt-get -y install cmake make gcc g++ flex bison libpcap-dev libssl-dev python-dev swig zlib1g-dev ant zip nmap texinfo oracle-java8-jdk



#Install Bro
echo "Installing Bro"
sudo wget https://www.bro.org/downloads/release/bro-2.4.1.tar.gz
sudo tar -xzf bro-2.4.1.tar.gz
sudo mkdir /opt/nsm
sudo mkdir /opt/nsm/bro
cd bro-2.4.1
sudo ./configure --prefix=/opt/nsm/bro
sudo make     
sudo make install
cd ..
sudo rm bro-2.4.1.tar.gz
sudo rm -rf bro-2.4.1/


#Install Critical Stack
echo "Installing Critical Stack Agent"
sudo wget http://intel.criticalstack.com/client/critical-stack-intel-arm.deb
sudo dpkg -i critical-stack-intel-arm.deb
#sudo -u critical-stack critical-stack-intel api $cs_api 
sudo -u critical-stack critical-stack-intel api fd7477ed-2bad-4452-4e06-75a6c9b1085f
sudo rm critical-stack-intel-arm.deb
sudo -u critical-stack critical-stack-intel config --set=bro.path=/opt/nsm/bro
sudo -u critical-stack critical-stack-intel config --set=bro.broctl.path=/opt/nsm/bro/bin/broctl
sudo bash -c 'echo "critical-stack ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)'

cd /home/pi

#Install ElasticSearch
echo "Installing Elastic Search"
sudo wget https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-2.3.2.deb
sudo dpkg -i elasticsearch-2.3.2.deb
sudo rm elasticsearch-2.3.2.deb
sudo update-rc.d elasticsearch defaults 95 10


#Install LogStash
echo "Installing Logstash"
sudo wget https://download.elastic.co/logstash/logstash/packages/debian/logstash_2.3.2-1_all.deb
sudo dpkg -i logstash_2.3.2-1_all.deb
sudo rm logstash_2.3.2-1_all.deb
cd /home/pi
sudo git clone https://github.com/jnr/jffi.git
cd jffi
sudo ant jar
sudo cp build/jni/libjffi-1.2.so /opt/logstash/vendor/jruby/lib/jni/arm-Linux
cd /opt/logstash/vendor/jruby/lib
sudo zip -g jruby-complete-1.7.11.jar jni/arm-Linux/libjffi-1.2.so
cd /home/pi
sudo rm -rf jffi/
#sudo cp SweetSecurity/init.d/logstash /etc/init.d
sudo update-rc.d logstash defaults 95 10
sudo /opt/logstash/bin/logstash-plugin install logstash-filter-translate
#sudo cp SweetSecurity/logstash.conf /etc/logstash/conf.d

sudo mkdir /etc/logstash/custom_patterns
sudo cp SweetSecurity/bro.rule /etc/logstash/custom_patterns
sudo mkdir /etc/logstash/translate

cd /etc/logstash/conf.d/
sudo wget -N https://raw.githubusercontent.com/timfrazier1/logstash-dfir/master/conf_files/bro/bro-conn_log.conf
sudo wget -N https://raw.githubusercontent.com/timfrazier1/logstash-dfir/master/conf_files/bro/bro-dns_log.conf
sudo wget -N https://raw.githubusercontent.com/timfrazier1/logstash-dfir/master/conf_files/bro/bro-files_log.conf
sudo wget -N https://raw.githubusercontent.com/timfrazier1/logstash-dfir/master/conf_files/bro/bro-http_log.conf
sudo wget -N https://raw.githubusercontent.com/timfrazier1/logstash-dfir/master/conf_files/bro/bro-notice_log.conf
sudo wget -N https://raw.githubusercontent.com/timfrazier1/logstash-dfir/master/conf_files/bro/bro-ssh_log.conf
sudo wget -N https://raw.githubusercontent.com/timfrazier1/logstash-dfir/master/conf_files/bro/bro-ssl_log.conf
sudo wget -N https://raw.githubusercontent.com/timfrazier1/logstash-dfir/master/conf_files/bro/bro-weird_log.conf
sudo wget -N https://raw.githubusercontent.com/timfrazier1/logstash-dfir/master/conf_files/bro/bro-x509_log.conf

sudo sed -i 's/\"\/nsm\/bro\/logs\/current/\"\/opt\/nsm\/bro\/logs\/current/g' ./*.conf

sudo sed -i 's/#LS_OPTS=\"\"/LS_OPTS=\"-w 2\"/g' /etc/default/logstash

cd /home/pi

#Install Kibana
echo "Installing Kibana"
sudo wget https://download.elastic.co/kibana/kibana/kibana-4.5.0-linux-x86.tar.gz
sudo tar -xzf kibana-4.5.0-linux-x86.tar.gz
sudo mv kibana-4.5.0-linux-x86/ /opt/kibana/
sudo apt-get -y remove nodejs-legacy nodejs nodered		#Remove nodejs on Pi3
sudo wget http://node-arm.herokuapp.com/node_latest_armhf.deb
sudo dpkg -i node_latest_armhf.deb
sudo mv /opt/kibana/node/bin/node /opt/kibana/node/bin/node.orig
sudo mv /opt/kibana/node/bin/npm /opt/kibana/node/bin/npm.orig
sudo ln -s /usr/local/bin/node /opt/kibana/node/bin/node
sudo ln -s /usr/local/bin/npm /opt/kibana/node/bin/npm
sudo rm node_latest_armhf.deb
sudo rm kibana-4.5.0-linux-x86.tar.gz
sudo cp SweetSecurity/init.d/kibana /etc/init.d
sudo chmod 755 /etc/init.d/kibana
sudo update-rc.d kibana defaults 95 10


#Restart services
echo "Restarting ELK services"
sudo service elasticsearch restart
sudo service kibana restart
sudo service logstash restart


#Deploy and start BroIDS
echo "Deploying and starting BroIDS"
sudo /opt/nsm/bro/bin/broctl deploy
sudo sed -i 's/exit 0/\/opt\/nsm\/bro\/bin\/broctl start\n&/' /etc/rc.local
