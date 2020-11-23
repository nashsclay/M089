#!/bin/bash

cd ~
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi
function configure_systemd {
  cat << EOF > /etc/systemd/system/deliond$ALIAS.service
[Unit]
Description=deliond$ALIAS service
After=network.target
[Service]
User=root
Group=root
Type=forking
#PIDFile=/root/.delion_$ALIAS/deliond.pid
ExecStart=/root/delionbin/deliond_$ALIAS.sh
ExecStop=-/root/delionbin/delion-cli_$ALIAS.sh stop
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
  crontab -l > cron$ALIAS
  echo "@reboot systemctl start deliond$ALIAS" >> cron$ALIAS
  crontab cron$ALIAS
  rm cron$ALIAS
  systemctl start deliond$ALIAS.service
}

clear
echo "1 - Create new nodes"
echo "2 - Remove an existing node"
echo "3 - Upgrade an existing node"
echo "4 - List aliases"
echo "What would you like to do?"
read DO
echo ""
if [ $DO = "4" ]
then
ALIASES=$(find /root/.delion_* -maxdepth 0 -type d | cut -c22-)
echo -e "${GREEN}${ALIASES}${NC}"
echo ""
echo "1 - Create new nodes"
echo "2 - Remove an existing node"
echo "3 - Upgrade an existing node"
echo "4 - List aliases"
echo "What would you like to do?"
read DO
echo ""
fi
if [ $DO = "3" ]
then
perl -i -ne 'print if ! $a{$_}++' /etc/monit/monitrc >/dev/null 2>&1
echo "Enter the alias of the node you want to upgrade"
read ALIAS
  echo -e "Upgrading ${GREEN}${ALIAS}${NC}. Please wait."
  sed -i '/$ALIAS/d' .bashrc
  sleep 1
  ## Config Alias
  echo "alias ${ALIAS}_status=\"delion-cli -datadir=/root/.delion_$ALIAS masternode status\"" >> .bashrc
  echo "alias ${ALIAS}_stop=\"delion-cli -datadir=/root/.delion_$ALIAS stop && systemctl stop deliond$ALIAS\"" >> .bashrc
  echo "alias ${ALIAS}_start=\"/root/delionbin/delion_${ALIAS}.sh && systemctl start deliond$ALIAS\""  >> .bashrc
  echo "alias ${ALIAS}_config=\"nano /root/.delion_${ALIAS}/delion.conf\""  >> .bashrc
  echo "alias ${ALIAS}_getinfo=\"delion-cli -datadir=/root/.delion_$ALIAS getinfo\"" >> .bashrc
  configure_systemd
  sleep 1
  source .bashrc
  echo -e "${GREEN}${ALIAS}${NC} Successfully upgraded."
fi
if [ $DO = "2" ]
then
perl -i -ne 'print if ! $a{$_}++' /etc/monit/monitrc >/dev/null 2>&1
echo "Input the alias of the node that you want to delete"
read ALIASD
echo ""
echo -e "${GREEN}Deleting ${ALIASD}${NC}. Please wait."
## Removing service
systemctl stop deliond$ALIASD >/dev/null 2>&1
systemctl disable deliond$ALIASD >/dev/null 2>&1
rm /etc/systemd/system/deliond${ALIASD}.service >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
systemctl reset-failed >/dev/null 2>&1
## Stopping node
delion-cli -datadir=/root/.delion_$ALIASD stop >/dev/null 2>&1
sleep 5
## Removing monit and directory
rm /root/.delion_$ALIASD -r >/dev/null 2>&1
sed -i '/$ALIASD/d' .bashrc >/dev/null 2>&1
sleep 1
sed -i '/$ALIASD/d' /etc/monit/monitrc >/dev/null 2>&1
monit reload >/dev/null 2>&1
sed -i '/$ALIASD/d' /etc/monit/monitrc >/dev/null 2>&1
crontab -l -u root | grep -v deliond$ALIASD | crontab -u root - >/dev/null 2>&1
source .bashrc
echo -e "${ALIASD} Successfully deleted."
fi
if [ $DO = "1" ]
then
echo "1 - Easy mode"
echo "2 - Expert mode"
echo "Please select a option:"
read EE
echo ""
if [ $EE = "1" ] 
then
MAXC="16"
fi
if [ $EE = "2" ] 
then
echo ""
echo "Enter max connections value"
read MAXC
fi
DOSETUP="y"
if [ $DOSETUP = "y" ]
then
  echo -e "Installing ${GREEN}delion coin dependencies${NC}. Please wait."
  sudo apt-get update 
  sudo apt-get -y upgrade
  sudo apt-get -y dist-upgrade
  sudo apt-get update
  sudo apt-get install build-essential libtool autotools-dev autoconf pkg-config libssl-dev libboost-all-dev libminiupnpc-dev software-properties-common -y && add-apt-repository ppa:bitcoin/bitcoin && apt-get update -y && apt-get install libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libzmq3-dev libevent-pthreads-2.0-5 zip unzip bc curl nano -y
  sleep 2
  cd
  chmod +x /root/delion/*
  sudo cp -R  /root/delion/* /usr/local/bin
  mkdir -p ~/delionbin 
  echo 'export PATH=~/delionbin:$PATH' > ~/.bash_aliases
  source ~/.bashrc
  echo ""
fi

echo "How many nodes do you want to install on this server?"
read MNCOUNT
echo "Enter Starting RPC PORT"
read RPCPORT
let COUNTER=0
while [  $COUNTER -lt $MNCOUNT ]; do
 echo ""
 echo "Enter IP ADDRESS"
 read IP6
 echo ""
 PORT=15858
 PORTD=15858
 RPCPORT=$(($RPCPORT+$COUNTER))
  echo ""
  echo "Enter alias for new node"
  read ALIAS
  CONF_DIR=~/.delion_$ALIAS
  echo ""
  echo "Enter masternode private key for node $ALIAS"
  read PRIVKEY
  mkdir ~/.delion_$ALIAS
  cp -R /root/delionsnapshot/* ~/.delion_$ALIAS
  echo '#!/bin/bash' > ~/delionbin/deliond_$ALIAS.sh
  echo "deliond -daemon -conf=$CONF_DIR/delion.conf -datadir=$CONF_DIR "'$*' >> ~/delionbin/deliond_$ALIAS.sh
  echo '#!/bin/bash' > ~/delionbin/delion-cli_$ALIAS.sh
  echo "delion-cli -conf=$CONF_DIR/delion.conf -datadir=$CONF_DIR "'$*' >> ~/delionbin/delion-cli_$ALIAS.sh
  chmod 755 ~/delionbin/delion*.sh
  mkdir -p $CONF_DIR
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> delion.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> delion.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> delion.conf_TEMP
  echo "rpcport=$RPCPORT" >> delion.conf_TEMP
  echo "listen=1" >> delion.conf_TEMP
  echo "server=1" >> delion.conf_TEMP
  echo "daemon=1" >> delion.conf_TEMP
  echo "logtimestamps=1" >> delion.conf_TEMP
  echo "maxconnections=$MAXC" >> delion.conf_TEMP
  echo "masternode=1" >> delion.conf_TEMP
  echo "dbcache=20" >> delion.conf_TEMP
  echo "maxorphantx=5" >> delion.conf_TEMP
  echo "maxmempool=100" >> delion.conf_TEMP
  echo "" >> delion.conf_TEMP
  echo "" >> delion.conf_TEMP
  echo "bind=$IP6" >> delion.conf_TEMP
  echo "port=$PORTD" >> delion.conf_TEMP
  echo "externalip=$IP6:$PORT" >> delion.conf_TEMP
  echo "masternodeaddr=$IP6:$PORT" >> delion.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> delion.conf_TEMP
  echo "" >> delion.conf_TEMP
  echo "addnode=45.77.252.62:15858" >> delion.conf_TEMP
  echo "addnode=45.77.226.43:15858" >> delion.conf_TEMP
  echo "addnode=45.76.150.140:15858" >> delion.conf_TEMP
  echo "addnode=45.63.92.158:15858" >> delion.conf_TEMP
  mv delion.conf_TEMP $CONF_DIR/delion.conf
  echo ""
  echo -e "Your ip is ${GREEN}$IP6:$PORT${NC}"
  COUNTER=$((COUNTER+1))
	echo "alias ${ALIAS}_status=\"delion-cli -datadir=/root/.delion_$ALIAS masternode status\"" >> .bashrc
	echo "alias ${ALIAS}_stop=\"systemctl stop deliond$ALIAS\"" >> .bashrc
	echo "alias ${ALIAS}_start=\"systemctl start deliond$ALIAS\""  >> .bashrc
	echo "alias ${ALIAS}_config=\"nano /root/.delion_${ALIAS}/delion.conf\""  >> .bashrc
	echo "alias ${ALIAS}_getinfo=\"delion-cli -datadir=/root/.delion_$ALIAS getinfo\"" >> .bashrc
	echo "alias ${ALIAS}_resync=\"/root/delionbin/deliond_$ALIAS -resync\"" >> .bashrc
	echo "alias ${ALIAS}_reindex=\"/root/delionbin/deliond_$ALIAS -reindex\"" >> .bashrc
	## Config Systemctl
	configure_systemd
done
echo ""
echo "Commands:"
echo "ALIAS_start"
echo "ALIAS_status"
echo "ALIAS_stop"
echo "ALIAS_config"
echo "ALIAS_getinfo"
echo "ALIAS_resync"
echo "ALIAS_reindex"
fi
echo ""
echo "Instalasi Selesai"
exec bash
exit

