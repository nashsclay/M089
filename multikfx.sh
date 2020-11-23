#!/bin/bash

PORT=15858
RPCPORT=15959
CONF_DIR=~/.delion
SNAPSHOT_DIR=~/snapshot

cd ~
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
if [[ $(lsb_release -d) = *16.04* ]]; then
  COINZIP='https://github.com/delioncoin/delioncore/releases/download/1.2.1/ubuntu16.zip'
fi
if [[ $(lsb_release -d) = *18.04* ]]; then
  COINZIP='https://github.com/delioncoin/delioncore/releases/download/1.2.1/ubuntu18.zip'
fi
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

function configure_systemd {
  cat << EOF > /etc/systemd/system/delion.service
[Unit]
Description=Delion Core Service
After=network.target
[Service]
User=root
Group=root
Type=forking
#PIDFile=/root/.delion/deliond.pid
ExecStart=/usr/local/bin/deliond
ExecStop=-/usr/local/bin/delion-cli stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  sleep 6
  crontab -l > crondelion
  echo "@reboot systemctl start delion" >> crondelion
  crontab crondelion
  rm crondelion
  systemctl start delion.service
}

echo ""
echo ""
DOSETUP="y"

if [ $DOSETUP = "y" ]  
then
  sudo apt-get update
  sudo apt-get -y upgrade
  sudo apt-get -y dist-upgrade
  sudo apt-get update
  sudo apt-get install build-essential zip unzip libtool autotools-dev autoconf pkg-config libssl-dev libboost-all-dev libminiupnpc-dev software-properties-common -y && add-apt-repository ppa:bitcoin/bitcoin && apt-get update -y && apt-get install libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libzmq3-dev bc curl nano libevent-pthreads-2.0-5 -y

  cd /var
  sudo touch swap.img
  sudo chmod 600 swap.img
  sudo dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
  sudo mkswap /var/swap.img
  sudo swapon /var/swap.img
  sudo free
  sudo echo "/var/swap.img none swap sw 0 0" >> /etc/fstab
  cd
  
  wget $COINZIP
  unzip *.zip
  chmod +x delion*
  rm delion-qt delion-tx *.zip
  sudo cp delion* /usr/local/bin
  mkdir -p delion
  sudo mv delion-cli deliond /root/delion
  
  mkdir -p $SNAPSHOT_DIR
  cd $SNAPSHOT_DIR
  wget http://cdn.delion.xyz/snapshot.zip
  unzip snapshot.zip
  rm snapshot.zip

fi

 IP=$(curl -s4 api.ipify.org)
 echo ""
 echo "Configure your masternodes now!"
 echo "Detecting IP address:$IP"
 echo ""
 echo "Enter masternode private key"
 read PRIVKEY
 
 mkdir -p $CONF_DIR
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> delion.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> delion.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> delion.conf_TEMP
  echo "rpcport=$RPCPORT" >> delion.conf_TEMP
  echo "listen=1" >> delion.conf_TEMP
  echo "server=1" >> delion.conf_TEMP
  echo "daemon=1" >> delion.conf_TEMP
  echo "logtimestamps=1" >> delion.conf_TEMP
  echo "maxconnections=250" >> delion.conf_TEMP
  echo "masternode=1" >> delion.conf_TEMP
  echo "dbcache=20" >> delion.conf_TEMP
  echo "maxorphantx=5" >> delion.conf_TEMP
  echo "maxmempool=100" >> delion.conf_TEMP
  echo "" >> delion.conf_TEMP
  echo "port=$PORT" >> delion.conf_TEMP
  echo "externalip=$IP:$PORT" >> delion.conf_TEMP
  echo "masternodeaddr=$IP:$PORT" >> delion.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> delion.conf_TEMP
  mv delion.conf_TEMP $CONF_DIR/delion.conf
  echo ""
  echo -e "Your ip is ${GREEN}$IP:$PORT${NC}"

  ## copy snapshot
  cp -R $SNAPSHOT_DIR/* $CONF_DIR
	## Config Systemctl
	configure_systemd
  
echo ""
echo "Commands:"
echo -e "Start Delion Service: ${GREEN}systemctl start delion${NC}"
echo -e "Check Delion Status Service: ${GREEN}systemctl status delion${NC}"
echo -e "Stop Delion Service: ${GREEN}systemctl stop delion${NC}"
echo -e "Check Masternode Status: ${GREEN}delion-cli masternode status${NC}"

echo ""
echo -e "${GREEN}Delion Masternode Installation Done${NC}"
exec bash
exit

