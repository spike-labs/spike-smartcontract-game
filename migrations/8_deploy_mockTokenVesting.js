const MockTokenVesting = artifacts.require("MockTokenVesting");
const GovernanceToken = artifacts.require("GovernanceToken");
 
module.exports = async function (deployer) {
  await deployer.deploy(MockTokenVesting, GovernanceToken.address);
  console.log("MockTokenVesting deployed: ", MockTokenVesting.address);
};