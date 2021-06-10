#!/bin/bash

DEVICE=/dev/xvdb
FS_TYPE=$(file -s $DEVICE | awk '{print $2}')
MOUNT_POINT=/home/ubuntu/.bcnad

# If no FS, then this output contains "data"
if [ "$FS_TYPE" = "no" ]
then
    echo "Creating file system on $DEVICE"
    sudo mkfs -t ext4 $DEVICE
fi

mkdir $MOUNT_POINT
sudo chown -R ubuntu:ubuntu $MOUNT_POINT
sudo mount $DEVICE $MOUNT_POINT

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y build-essential curl wget jq

sudo su -c "echo 'fs.file-max = 65536' >> /etc/sysctl.conf"
sudo sysctl -p

sudo rm -rf /usr/local/go
curl https://dl.google.com/go/go1.15.7.linux-amd64.tar.gz | sudo tar -C/usr/local -zxvf -
cat <<'EOF' >>$HOME/.profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF
source $HOME/.profile

cd $HOME
wget https://github.com/BitCannaGlobal/testnet-bcna-cosmos/releases/download/v0.testnet6/bcnad
chmod +x bcnad
sudo mv bcnad /usr/local/bin/

bcnad init Moniker --chain-id bitcanna-testnet-2

cd $HOME
wget https://raw.githubusercontent.com/BitCannaGlobal/testnet-bcna-cosmos/main/instructions/stage1/genesis.json 
mv genesis.json $HOME/.bcna/config/

sed -E -i 's/seeds = \".*\"/seeds = \"d6aa4c9f3ccecb0cc52109a95962b4618d69dd3f@seed1.bitcanna.io:26656,8e241ba2e8db2e83bb5d80473b4fd4d901043dda@178.128.247.173:26656,41d373d03f93a3dc883ba4c1b9b7a781ead53d76@seed2.bitcanna.io:16656\"/' $HOME/.bcna/config/config.toml
sed -E -i 's/persistent_peers = \".*\"/persistent_peers = \"d6aa4c9f3ccecb0cc52109a95962b4618d69dd3f@seed1.bitcanna.io:26656,41d373d03f93a3dc883ba4c1b9b7a781ead53d76@seed2.bitcanna.io:16656\"/' $HOME/.bcna/config/config.toml
sed -E -i 's/minimum-gas-prices = \".*\"/minimum-gas-prices = \"0.01ubcna\"/' $HOME/.bcna/config/app.toml

sudo ufw allow 26656

sudo tee <<EOF >/dev/null /etc/systemd/system/bcnad.service
[Unit]
Description=BitCanna Node
After=network-online.target

[Service]
User=ubuntu
ExecStart=/usr/local/bin/bcnad start
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable bcnad.service
sudo systemctl daemon-reload
sudo systemctl start bcnad.service
