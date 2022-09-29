const helper = require("./helper.js");
const GovernanceToken = artifacts.require("GovernanceToken");
const tokenConfig = require("../tokenConfig.json")
const deploymentsFile = "./deployments.json";
module.exports = async function (deployer, network) {
  let deployments
  helper.jsonReader(deploymentsFile, (err, deploymentsData) => {
    if (err) {
      console.log("Error reading file:", err);
      return;
    }
    deployments = deploymentsData;
  });

  let govToken = tokenConfig.govToken;
  await deployer.deploy(GovernanceToken, govToken.name, govToken.symbol, govToken.cap);
  console.log(`GovernanceToken ${govToken.symbol} deployed: ${GovernanceToken.address}`);
  // Instance creation
  let govTokenInstance = await GovernanceToken.deployed();
  // Transfer ownership
  if (govToken.owner) {
    if (web3.utils.isAddress(govToken.owner)) {
      await govTokenInstance.transferOwnership(govToken.owner, true);
      console.log(`Done to transfer ownership to ${govToken.owner}`);
    } else {
      console.log("Failed to transfer ownership, invalid owner address configured.");
    }
  }
  
  if (deployments[network] == undefined) deployments[network] = {}
  deployments[network][govToken.symbol] = GovernanceToken.address;
  helper.jsonWriter(deploymentsFile, deployments);  
};


