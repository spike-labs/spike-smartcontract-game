## Prerequisite to use this repo
1. This is one truffle project, please install truffle at first

`npm install truffle -g`

2.  Install other dependencies

`npm install`

## How to configure
1. Configure account to deploy smart contracts
Rename .env.example to .env and configure private key/mnemonic string as mnemonic value

2. Configure networks
Only BNB chain is supported for now. For other networks, please configure them in truffle-config.js.

3. Configure the tokens to be deployed
Four type of tokens are supported for now:

- Governance Token

Normally one GameFI app has one Governance token for community governance purpose.

You can configure the name, symbol, cap and owner in tokenConfig.json. By default the owner is set to the deployer account for all smart contracts, the ownership will be transferred to the new owner account if it's configured properly.

- Game Token

You could configure name, symbol and owner for one or more game tokens in tokenConfig.json.

- Game NFT

You could configure name, symbol, mintAdmins and owner for one or more game NFTs in tokenConfig.json. Only configured mint admins have permission to mint new NFTs.


- GameVault

Game vault is used to store user assets in spending wallet. You could configure withdraw admins in tokenConfig.json. Only withdraw admins have permission to withdraw tokens from game vault.

## How to deploy
Run below command to deploy all the required smart contracts.

`npm run deployTokens -- --network <network>`

Please replace <network> with the network name you configured.

Once the commond runs successfully. You could view the smart contract addresses in tokenConfig.json.

## How to verify
You could use the files inside flats folder to verify the smart contracts manually via blockchain explorer.

## How to get abi files
All abi files are placed in abi folder.

## How to mint tokens
`truffle exec scripts/mintToken.js --token <token address> --to <token receiver address> --amount <mint amount> --network <network name>`

eg: truffle exec scripts/mintGovToken.js --token 0xCb8DAD63dD2cE2832AcFB2F7f4AC1f67d698FB46 --to 0x758F390696c7d1eb669E02909A6395e5D852665B --amount 1200000000000 --network development