#!/bin/sh
set -eu

# rm -rf $(pwd)/validator_keys
# docker run -it --rm -v $(pwd)/validator_keys:/app/validator_keys clydekuo/staking-deposit-cli  --language=English  new-mnemonic --num_validators=2   --mnemonic_language=english  --chain=testnet 


# Creates a genesis state for the beacon chain using a YAML configuration file 
deposit_data=$(ls validator_keys/deposit_data-*.json)
docker run --rm \
  -v "$(pwd)/config:/config" \
  -v "$(pwd)/execution:/execution" \
  -v "$(pwd)/consensus:/consensus" \
  -v "$(pwd)/validator_keys:/validator_keys" \
  gcr.io/prysmaticlabs/prysm/cmd/prysmctl \
  testnet \
  generate-genesis \
  --num-validators 2 \
  --chain-config-file /config/beacon-chain-config.yml \
  --deposit-json-file /$deposit_data \
  --geth-genesis-json-in /config/genesis.json \
  --geth-genesis-json-out /config/genesis.json \
  --output-ssz /consensus/genesis.ssz

echo "Generate genesis success!"

rm -rf $(pwd)/execution/
docker run --rm \
  -v "$(pwd)/execution":/execution \
  gcr.io/prysmaticlabs/prysm/beacon-chain:v4.1.1 \
  generate-auth-secret \
  -o /execution/jwtsecret

echo "Generate jwtsecret success!"

# Sets up the genesis configuration for the go-ethereum client from a JSON file.
docker run --rm \
  -v "$(pwd)/execution:/execution" \
  -v "$(pwd)/config:/config" \
  ethereum/client-go:latest \
  init \
  --datadir=/execution \
  --state.scheme=hash \
  /config/genesis.json

echo "Initialize geth success!"

rm -rf $(pwd)/consensus/
docker run --rm --name validator -it \
  -v "$(pwd)/consensus:/consensus" \
  -v "$(pwd)/validator_keys:/validator_keys" \
  gcr.io/prysmaticlabs/prysm/validator:v4.1.1 \
  accounts \
  import \
  --keys-dir=/validator_keys \
  --wallet-dir=/consensus/prysmwallet \
  --accept-terms-of-use