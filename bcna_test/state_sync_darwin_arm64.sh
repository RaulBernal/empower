#!/bin/bash
# Based on the work of Joe (Chorus-One) for Microtick - https://github.com/microtick/bounties/tree/main/statesync
# You need config in two peers (avoid seed servers) this values in app.toml:
#     [state-sync]
#     snapshot-interval = 1000
#     snapshot-keep-recent = 10
# Pruning should be fine tuned also, for this testings is set to nothing
#     pruning = "nothing"

# Let's check if JQ tool is installed
FILE=$(which jq)
 if [ -f "$FILE" ]; then
   echo "JQ is present"
 else
   echo "$FILE JQ tool does not exist, install with: sudo apt install jq"
   exit 1
 fi

set -e

# Change for your custom chain
BINARY="https://github.com/RaulBernal/empower/releases/download/v2/bcna_darwin_arm64.tar.gz"
GENESIS="https://raw.githubusercontent.com/RaulBernal/empower/main/bcna_test/genesis.json"
APP="BCNA: ~/.bcna"
echo "Welcome to the StateSync script. This script will download the last binary and it will sync the last state."
echo "DON'T USE WITH A EXISTENT peer/validator config will be erased."
echo "You should have a crypted backup of your wallet keys, your node keys and your validator keys." 
echo "Ensure that you can restore your wallet keys if is needed."
read -p "have you stopped the BCNAD service? CTRL + C to exit or any key to continue..."
read -p "$APP folder, your keys and config WILL BE ERASED, it's ok if you want to build a peer/validator for first time, PROCED (y/n)? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # BitCanna State Sync client config.
  echo ###########################################
  echo "     Starting StateSync process..."
  echo ###########################################
  cd ~
  if [ -d ~/.bcna ];
  then
    echo "There is a BCNA folder there... if you want sync the data in an existent peer/validator try the script: statesync_linux_existising.sh"
    exit 1
  else
      echo "New installation...."
  fi
  rm -f bcnad #deletes a previous downloaded binary
  rm -f bcna_darwin_arm64.tar.gz
  wget -nc $BINARY
  tar zxvf bcna_darwin_arm64.tar.gz
  rm bcna_darwin_arm64.tar.gz
  chmod +x bcnad
  ./bcnad init New_peer --chain-id bitcanna-dev-2
  rm -rf $HOME/.bcnad/config/genesis.json #deletes the default created genesis
  curl -s $GENESIS > $HOME/.bcna/config/genesis.json
  
 
  NODE1_IP="164.68.119.233"
  RPC1="http://$NODE1_IP"
  P2P_PORT1=46656
  RPC_PORT1=46657

  NODE2_IP="164.68.119.233"
  RPC2="http://$NODE2_IP"
  RPC_PORT2=46657
  P2P_PORT2=46656

  #If you want to use a third StateSync Server... 
  #DOMAIN_3=seed1.bitcanna.io     # If you want to use domain names 
  #NODE3_IP=$(dig $DOMAIN_1 +short
  #RPC3="http://$NODE3_IP"
  #RPC_PORT3=26657
  #P2P_PORT3=26656

  INTERVAL=1000

  LATEST_HEIGHT=$(curl -s $RPC1:$RPC_PORT1/block | jq -r .result.block.header.height);
  BLOCK_HEIGHT=$((($(($LATEST_HEIGHT / $INTERVAL)) -10) * $INTERVAL)); #Mark addition
  
  if [ $BLOCK_HEIGHT -eq 0 ]; then
    echo "Error: Cannot state sync to block 0; Latest block is $LATEST_HEIGHT and must be at least $INTERVAL; wait a few blocks!"
    exit 1
  fi

  TRUST_HASH=$(curl -s "$RPC1:$RPC_PORT1/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
  if [ "$TRUST_HASH" == "null" ]; then
    echo "Error: Cannot find block hash. This shouldn't happen :/"
    exit 1
  fi

  NODE1_ID=$(curl -s "$RPC1:$RPC_PORT1/status" | jq -r .result.node_info.id)
  NODE2_ID=$(curl -s "$RPC2:$RPC_PORT2/status" | jq -r .result.node_info.id)
  #NODE3_ID=$(curl -s "$RPC3:$RPC_PORT3/status" | jq -r .result.node_info.id)

  sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
  s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"http://$NODE1_IP:$RPC_PORT1,http://$NODE2_IP:$RPC_PORT2\"| ; \
  s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
  s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
  s|^(persistent_peers[[:space:]]+=[[:space:]]+).*$|\1\"${NODE1_ID}@${NODE1_IP}:${P2P_PORT1},${NODE2_ID}@${NODE2_IP}:${P2P_PORT2}\"| ; \
  s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"d6aa4c9f3ccecb0cc52109a95962b4618d69dd3f@seed1.bitcanna.io:26656,23671067d0fd40aec523290585c7d8e91034a771@seed2.bitcanna.io:26656\"|" $HOME/.bcna/config/config.toml


  sed -E -i -s 's/minimum-gas-prices = \".*\"/minimum-gas-prices = \"0.001ubcna\"/' $HOME/.bcna/config/app.toml

  ./bcnad tendermint unsafe-reset-all --home $HOME/.bcna
  echo ##################################################################
  echo  "PLEASE HIT CTRL+C WHEN THE CHAIN IS SYNCED, Wait the last block"
  echo ##################################################################
  sleep 5
  ./bcnad start
  sed -E -i 's/enable = true/enable = false/' $HOME/.bcna/config/config.toml
  echo ##################################################################  
  echo  Run again with: ./bcnad start
  echo ##################################################################
  echo If your node is synced considerate to create a service file. 
fi
