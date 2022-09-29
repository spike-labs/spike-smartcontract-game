const GameToken = artifacts.require("GameToken");
const tokenConfig = require("../tokenConfig.json");
const deploymentsFile = "./deployments.json";
const helper = require("../migrations/helper.js");
const yargs = require('yargs');
const argv = yargs.options('token', {type: 'string'})
                  .options("to", {type: 'string'})
                  .options("amount")
                  .options("network")
                  .argv
module.exports = async function(callback) {
    try {
      let gameTokenInstance = await GameToken.at(argv.token);
      let symbol = await gameTokenInstance.symbol();
      await gameTokenInstance.mint(argv.to, argv.amount);
      console.log(argv.amount, symbol, "minted")
        callback();
    } catch (e) {
        console.log(e)
        callback(e);
    }
}
