const GameVault = artifacts.require("GameVault");
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


  let gameVault = tokenConfig.gameVault;
  await deployer.deploy(GameVault);
  console.log("GameVault deployed: ", GameVault.address)

  const gameVaultInstance = await GameVault.deployed();

  if (gameVault.withdrawAdmins.length == 0) {
    console.log("Withdraw admins should be configured for GameVault.")
    process.exit();
  }
  for (let withdrawAdmin of gameVault.withdrawAdmins) {
    await gameVaultInstance.enableAdmin(withdrawAdmin);
    console.log(`${withdrawAdmin} is added as withdraw admin`);
  }
  // Transfer ownership
  if (gameVault.owner) {
    if (web3.utils.isAddress(gameVault.owner)) {
      await gameVaultInstance.transferOwnership(gameVault.owner, true);
      console.log(`Done to transfer ownership to ${gameVault.owner}`);
    } else {
      console.log("Failed to transfer ownership, invalid owner address configured.");
    }
  }
  
  if (deployments[network] == undefined) deployments[network] = {}
  deployments[network]["GameVault"] = GameVault.address;
  helper.jsonWriter(deploymentsFile, deployments);  
};