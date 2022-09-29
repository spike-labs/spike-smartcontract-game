const GovernanceToken = artifacts.require("GovernanceToken");

contract("GovernanceToken", (accounts) => {

    it("should mint tokens properly when amount not exceed cap setting", async () => {
        let governanceTokenInstance = await GovernanceToken.new("SKK", "SKK", "1000");
        console.log("governanceTokenInstance address: ", governanceTokenInstance.address);
        await governanceTokenInstance.mint(accounts[0], "100");
        let accountBalance = await governanceTokenInstance.balanceOf(accounts[0]);
        assert.equal(accountBalance.toString(), "100");
    });

    it("should not mint tokens exceed cap setting", async () => {
        let governanceTokenInstance = await GovernanceToken.new("SKK", "SKK", "1000");
        console.log("governanceTokenInstance address: ", governanceTokenInstance.address);
        try {
            await governanceTokenInstance.mint(accounts[0], "1000");
            await governanceTokenInstance.mint(accounts[0], "1");
            assert(false)
        } catch(err) {
            assert(err)
        }
    });
});