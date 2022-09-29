const GameNFT = artifacts.require("GameNFT");
const tokenConfig = require("../tokenConfig.json");
const deploymentsFile = "./deployments.json";
const helper = require("./helper.js");
module.exports = async function (deployer, network) {
  let deployments
  helper.jsonReader(deploymentsFile, (err, deploymentsData) => {
    if (err) {
      console.log("Error reading file:", err);
      return;
    }
    deployments = deploymentsData;
  });


  for (let gameNFT of tokenConfig.gameNFTs) {
    await deployer.deploy(GameNFT, gameNFT.name, gameNFT.symbol);
    console.log("GameNFT deployed: ", GameNFT.address);
    if (deployments[network] == undefined) deployments[network] = {}
    deployments[network][gameNFT.symbol] = GameNFT.address
    let gameNFTInstance = await GameNFT.deployed();

    if (gameNFT.mintAdmins.length == 0) {
      console.log("Mint admins should be configured for GameNFT.")
      process.exit();
    }
    for (let mintAdmin of gameNFT.mintAdmins) {
      await gameNFTInstance.enableAdmin(mintAdmin);
      console.log(`${mintAdmin} is added as mint admin`);
    }

    // Transfer ownership
    if (gameNFT.owner) {
      if (web3.utils.isAddress(gameNFT.owner)) {
       await gameNFTInstance.transferOwnership(gameNFT.owner, true);
       console.log(`Done to transfer ownership to ${gameNFT.owner}`);
      } else {
       console.log("Failed to transfer ownership, invalid owner address configured.");
      }
    }
  }

  helper.jsonWriter(deploymentsFile, deployments);  
};