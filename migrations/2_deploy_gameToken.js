const GameToken = artifacts.require("GameToken");
const tokenConfig = require("../tokenConfig.json");
const deploymentsFile = "./deployments.json";
const helper = require("./helper.js");
module.exports = async function (deployer, network) {
  let deployments = {}
  helper.jsonReader(deploymentsFile, (err, deploymentsData) => {
    if (err) {
      console.log("Error reading file:", err);
      return;
    }
    deployments = deploymentsData;
  });

  for (let gameToken of tokenConfig.gameTokens) {
     // Deployment
     await deployer.deploy(GameToken, gameToken.name, gameToken.symbol);
     console.log(`GameToken ${gameToken.symbol} deployed: ${GameToken.address}`);
     if (deployments[network] == undefined) deployments[network] = {}
     deployments[network][gameToken.symbol] = GameToken.address;
     // Instance creation
     let gameTokenInstance = await GameToken.deployed();
     // Transfer ownership
     if (gameToken.owner) {
       if (web3.utils.isAddress(gameToken.owner)) {
        await gameTokenInstance.transferOwnership(gameToken.owner, true);
        console.log(`Done to transfer ownership to ${gameToken.owner}`);
       } else {
        console.log("Failed to transfer ownership, invalid owner address configured.");
       }
     }
  }

  helper.jsonWriter(deploymentsFile, deployments);  
};
