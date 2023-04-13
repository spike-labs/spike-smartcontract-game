const GameComponentNFT = artifacts.require("GameComponentNFT");
 
module.exports = async function (deployer, network, accounts) {
    await deployer.deploy(GameComponentNFT, "Spike Module NFT", "SMNFT");
    console.log("GameComponentNFT deployed: ", GameComponentNFT.address);
};