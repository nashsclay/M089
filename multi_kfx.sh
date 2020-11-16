#!/bin/bash

PORT=19328
RPCPORT=15959
CONF_DIR=~/.kfx
SNAPSHOT_DIR=~/snapshot

cd ~
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
if [[ $(lsb_release -d) = *16.04* ]]; then
  COINZIP='https://github.com/KnoxFS/kfx-wallet/releases/download/3.2.0/kfx-3.2.0-x86_64-Linux.tar.gz'
fi
if [[ $(lsb_release -d) = *18.04* ]]; then
  COINZIP='https://github.com/KnoxFS/kfx-wallet/releases/download/3.2.0/kfx-3.2.0-x86_64-Linux.tar.gz'
fi
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

delion

function configure_systemd {
  cat << EOF > /etc/systemd/system/kfx.service
[Unit]
Description=KFX Core Service
After=network.target
[Service]
User=root
Group=root
Type=forking
#PIDFile=/root/.kfx/kfxd.pid
ExecStart=/usr/local/bin/kfxd
ExecStop=-/usr/local/bin/kfx-cli stop
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
  crontab -l > cronkfx
  echo "@reboot systemctl start kfx" >> cronkfx
  crontab cronkfx
  rm cronkfx
  systemctl start kfx.service
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
  chmod +x kfx*
  rm kfx-qt kfx-tx *.zip
  sudo cp kfx* /usr/local/bin
  mkdir -p kfx
  sudo mv kfx-cli kfxd /root/kfx
  
  mkdir -p $SNAPSHOT_DIR
  cd $SNAPSHOT_DIR
  wget https://bs-king.org/coins/kfx/kfx.zip
  unzip kfx.zip
  rm kfx.zip

fi

 IP=$(curl -s4 api.ipify.org)
 echo ""
 echo "Configure your masternodes now!"
 echo "Detecting IP address:$IP"
 echo ""
 echo "Enter masternode private key"
 read PRIVKEY
 
 mkdir -p $CONF_DIR
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> kfx.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> kfx.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> kfx.conf_TEMP
  echo "rpcport=$RPCPORT" >> kfx.conf_TEMP
  echo "listen=1" >> kfx.conf_TEMP
  echo "server=1" >> kfx.conf_TEMP
  echo "daemon=1" >> kfx.conf_TEMP
  echo "logtimestamps=1" >> kfx.conf_TEMP
  echo "maxconnections=250" >> kfx.conf_TEMP
  echo "masternode=1" >> kfx.conf_TEMP
  echo "dbcache=20" >> kfx.conf_TEMP
  echo "maxorphantx=5" >> kfx.conf_TEMP
  echo "maxmempool=100" >> kfx.conf_TEMP
  echo "" >> kfx.conf_TEMP
  echo "port=$PORT" >> kfx.conf_TEMP
  echo "externalip=$IP:$PORT" >> kfx.conf_TEMP
  echo "masternodeaddr=$IP:$PORT" >> kfx.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> kfx.conf_TEMP
  mv kfx.conf_TEMP $CONF_DIR/kfx.conf
  echo ""
  echo -e "Your ip is ${BLUE}$IP:$PORT${NC}"

  ## copy snapshot
  cp -R $SNAPSHOT_DIR/* $CONF_DIR
	## Config Systemctl
	configure_systemd
  
echo ""
echo "Commands:"
echo -e "Start KFX Service: ${BLUE}systemctl start kfx${NC}"
echo -e "Check KFX  Status Service: ${BLUE}systemctl status kfx${NC}"
echo -e "Stop KFX  Service: ${BLUE}systemctl stop kfx${NC}"
echo -e "Check Masternode Status: ${BLUE}kfx-cli masternode status${NC}"

echo ""
echo -e "${BLUE}KNOX Masternode Installation Done${NC}"
exec bash
exit