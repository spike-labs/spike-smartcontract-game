const TokenVesting = artifacts.require("TokenVesting");
const GovernanceToken = artifacts.require("GovernanceToken");
 
module.exports = async function (deployer) {
  await deployer.deploy(TokenVesting, GovernanceToken.address);
  console.log("TokenVesting deployed: ", TokenVesting.address);
};