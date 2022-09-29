const NFTWhitelist = artifacts.require("NFTWhitelist");
 
module.exports = async function (deployer, network, accounts) {
    const merkleRoot = "0xd3c842cfa62b8ce7ba8930713e48a9c5a1decf740b7cc53252850233e0ece6a7";
    await deployer.deploy(NFTWhitelist, merkleRoot, accounts[0]);
    console.log("NFTWhitelist deployed: ", NFTWhitelist.address);
};