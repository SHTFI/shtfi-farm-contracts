require("dotenv").config({ path: "../.env" });
const ShitFarm = artifacts.require("ShitFarm");
const ShitToken = artifacts.require("ShitToken");
const MOCKToken = artifacts.require("MockBEP20");

module.exports = function (deployer) {
  deployer.then(async () => {
    const currentBlock = await web3.eth.getBlockNumber();
    // Deploy SHIT
    await deployer.deploy(ShitToken);
    // Create an instance of it
    const ShitTokenInstance = await ShitToken.deployed();

    // Deploy ShitFarm
    await deployer.deploy(
      ShitFarm, // The contract to deploy
      ShitTokenInstance.address, // The address of shit token (reward token)
      "10000000000000000000", // The amount of reward token to dist per block -- 18 DP
      currentBlock + 100 // Starting block
    );
    // ShitFarm instance
    const ShitFarmInstance = await ShitFarm.deployed();
    // Set the farm address
    await ShitTokenInstance.setFarm(ShitFarmInstance.address); // Farm address is the only minter

    // Deploy our mock token to test staking
    await deployer.deploy(
      MOCKToken,
      "Mock Token",
      "MOCK",
      "10000000000000000000000"
    );
    // Get the interface
    const MockTokenInterface = await MOCKToken.deployed();
    // Add farm for Mock token
    await ShitFarmInstance.add(
      50,
      MockTokenInterface.address,
      currentBlock + 100,
      true
    );
  });
};
