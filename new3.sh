#!/bin/bash

PORT=19328
RPCPORT=19328
CONF_DIR=~/.kfx
SNAPSHOT_DIR=~/snapshot

cd ~
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
if [[ $(lsb_release -d) = *16.04* ]]; then
  COINZIP='https://github.com/KnoxFS/kfx-wallet/releases/download/3.2.0/kfx-3.2.0-x86_64-Linux.tar.gz'
fi

if [[ $(lsb_release -d) = *20.04* ]]; then
  COINZIP='https://github.com/KnoxFS/kfx-wallet/releases/download/3.2.0/kfx-3.2.0-x86_64-Linux.tar.gz'
fi


if [[ $(lsb_release -d) = *18.04* ]]; then
  COINZIP='https://github.com/KnoxFS/kfx-wallet/releases/download/3.2.0/kfx-3.2.0-x86_64-Linux.tar.gz'
fi
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

kfx


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