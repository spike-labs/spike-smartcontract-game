const GameVault = artifacts.require("GameVault");
const GameToken = artifacts.require("GameToken");
const GameNFT = artifacts.require("GameNFT");
const DefaultRiskControlStrategy = artifacts.require("DefaultRiskControlStrategy");

contract("GameVault", (accounts) => {


    beforeEach(async function () {
        const gameTokenInstance = await GameToken.deployed();
        const gameVaultInstance = await GameVault.deployed();
        await gameTokenInstance.mint(gameVaultInstance.address, "100000000000000000000");
        await gameVaultInstance.sendTransaction({value:  web3.utils.toWei('1', 'ether')});
    });

    it("should withdraw erc20 token properly", async () => {
        const gameTokenInstance = await GameToken.deployed();
        const gameVaultInstance = await GameVault.deployed();
        const gameTokenBalance = await gameVaultInstance.getTokenBalance(gameTokenInstance.address);
        console.log("gameTokenBalance: ", gameTokenBalance.toString());
        const amountToWithdraw = "10000000000000000000";
        const withdrawToAccount = accounts[1];
        await gameVaultInstance.withdraw(gameTokenInstance.address, withdrawToAccount, amountToWithdraw);
        const balanceAfterWithdraw = await gameTokenInstance.balanceOf(withdrawToAccount);
        assert.equal(amountToWithdraw, balanceAfterWithdraw.toString(), "bad withdraw");

        const riskStrategyInstance = await DefaultRiskControlStrategy.deployed();
        await gameVaultInstance.setRiskControlStrategy(riskStrategyInstance.address);
        await riskStrategyInstance.setPaused(true);

        try {
            await gameVaultInstance.batchWithdraw([gameTokenInstance.address], [withdrawToAccount], [amountToWithdraw], {from: accounts[0]});
            assert(false);
        } catch (err) {
            assert(err);
        }

        try {
            await gameVaultInstance.batchWithdraw(gameTokenInstance.address, [withdrawToAccount], [amountToWithdraw], {from: accounts[0]});
            assert(false);
        } catch (err) {
            assert(err);
        }
        await riskStrategyInstance.setPaused(false);
        try {
            await gameVaultInstance.batchWithdraw([gameTokenInstance.address, gameTokenInstance.address], [withdrawToAccount, withdrawToAccount], [amountToWithdraw, amountToWithdraw], {from: accounts[0]});
            assert(true);
        } catch (err) {
            console.log(err)
            assert(false);
        }
    });

    it("should withdraw native token properly", async () => {
        const toBN = web3.utils.toBN;
        const nativeToken = "0x0000000000000000000000000000000000000000";
        const gameVaultInstance = await GameVault.deployed();
        const nativeTokenBalance = await gameVaultInstance.getTokenBalance("0x0000000000000000000000000000000000000000");
        console.log("gameTokenBalance: ", nativeTokenBalance.toString());
        const amountToWithdraw = "100000000000000000";
        const withdrawToAccount = accounts[1];
        const balanceBeforeWithdraw = await web3.eth.getBalance(withdrawToAccount);
        const checkBalanceBN = toBN(balanceBeforeWithdraw).add(toBN(amountToWithdraw))
        await gameVaultInstance.withdraw(nativeToken, withdrawToAccount, amountToWithdraw);
        const balanceAfterWithdraw = await web3.eth.getBalance(withdrawToAccount);
        assert.deepEqual(checkBalanceBN.toString(), balanceAfterWithdraw.toString(), "bad withdraw");
    });

    it("should withdraw NFT token properly", async () => {
        const gameVaultInstance = await GameVault.deployed();
        const gameNFTInstance = await GameNFT.deployed();
        await gameNFTInstance.mint(0, gameVaultInstance.address);
        await gameNFTInstance.mint(1, gameVaultInstance.address, "");
        await gameNFTInstance.mint(2, gameVaultInstance.address, "");
        await gameNFTInstance.mint(3, gameVaultInstance.address, "");
        await gameNFTInstance.mint(4, gameVaultInstance.address, "");
        const nftTokenBalance = await gameVaultInstance.getTokenBalance(gameNFTInstance.address);
        console.log("gameTokenBalance: ", nftTokenBalance.toString());
        const withdrawToAccount = accounts[1];
        await gameVaultInstance.withdrawNFT(gameNFTInstance.address, withdrawToAccount, 0);
        const nftOwner = await gameNFTInstance.ownerOf(0);
        assert.equal(withdrawToAccount, nftOwner, "bad nft withdraw")

        // await gameVaultInstance.withdrawNFT(gameNFTInstance.address, withdrawToAccount, 1, {from: accounts[2]});

        const riskStrategyInstance = await DefaultRiskControlStrategy.deployed();
        await gameVaultInstance.setRiskControlStrategy(riskStrategyInstance.address);
        await riskStrategyInstance.setPaused(true);
        try {
            await gameVaultInstance.withdrawNFT(gameNFTInstance.address, withdrawToAccount, 1, {from: accounts[0]});
            assert(false);
        } catch (err) {
            assert(err);
        }

        try {
            await gameVaultInstance.batchWithdrawNFT(gameNFTInstance.address, [withdrawToAccount], [2], {from: accounts[0]});
            assert(false);
        } catch (err) {
            assert(err);
        }
        await riskStrategyInstance.setPaused(false);
        let latestBalance = await gameNFTInstance.balanceOf(accounts[2]);
        console.log("latestBalance before batch withdraw: ", latestBalance.toString())
        await gameVaultInstance.batchWithdrawNFT(gameNFTInstance.address, [accounts[2],accounts[2]], [3,4], {from: accounts[0]});
        latestBalance = await gameNFTInstance.balanceOf(accounts[2]);
        console.log("latestBalance after bath withdraw: ", latestBalance.toString())
        assert.equal(latestBalance.toString(), "2", "Failed batch transfer");
    });
});