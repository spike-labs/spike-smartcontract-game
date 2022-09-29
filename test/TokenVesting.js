const MockTokenVesting = artifacts.require("MockTokenVesting");
const GovernanceToken = artifacts.require("GovernanceToken"); 

contract("TokenVesting", (accounts) => {

    it("should only could release token after cliff period", async () => {
        let governanceTokenInstance = await GovernanceToken.deployed();
        let tokenVestingInstance = await MockTokenVesting.new(governanceTokenInstance.address);
        let beneficiary = accounts[1];
        let start = 0;
        let cliff = "31104000", duration = "62208000", slicePeriodSeconds = "2592000", revocable = true, amount = "3800000000000000000000000000";
        await tokenVestingInstance.createVestingSchedule(beneficiary, start, cliff, duration, slicePeriodSeconds, revocable, amount);
        await governanceTokenInstance.mint(tokenVestingInstance.address, "48900000000000000000000000000")
        await tokenVestingInstance.startVesting();
        await tokenVestingInstance.releaseForAll();
        let accountBalance = await governanceTokenInstance.balanceOf(accounts[1]);
        assert.equal(accountBalance.toString(), "0", "account balance not 0");
        await tokenVestingInstance.increaseTime(cliff);
        await tokenVestingInstance.releaseForAll();
        accountBalance = await governanceTokenInstance.balanceOf(accounts[1]);
        console.log("accountBalance: ", accountBalance.toString());

        await tokenVestingInstance.increaseTime(slicePeriodSeconds);
        await tokenVestingInstance.releaseForAll();
        accountBalance = await governanceTokenInstance.balanceOf(accounts[1]);
        console.log("accountBalance: ", accountBalance.toString());
    });
});