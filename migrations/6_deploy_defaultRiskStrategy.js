const DefaultRiskControlStrategy = artifacts.require("DefaultRiskControlStrategy");

module.exports = async function (deployer) {
  await deployer.deploy(DefaultRiskControlStrategy);
  console.log("DefaultRiskControlStrategy deployed: ", DefaultRiskControlStrategy.address)
};