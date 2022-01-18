require("dotenv").config({ path: "../.env" });
const ShtfiFarm = artifacts.require("ShtfiFarm");
const ShtfiToken = artifacts.require("ShtfiToken");
const MOCKToken = artifacts.require("MockBEP20");

module.exports = function (deployer) {
  deployer.then(async () => {
    const currentBlock = await web3.eth.getBlockNumber();
    // Deploy SHTFI
    await deployer.deploy(ShtfiToken);
    // Create an instance of it
    const ShtfiTokenInstance = await ShtfiToken.deployed();

    // Deploy ShtfiFarm
    await deployer.deploy(
      ShtfiFarm, // The contract to deploy
      ShtfiTokenInstance.address, // The address of SHTFI token (reward token)
      "20000000000000000", // The amount of reward token to dist per block -- 18 DP -- set to 0.02
      currentBlock + 100 // Starting block
    );
    // ShtfiFarm instance
    const ShtfiFarmInstance = await ShtfiFarm.deployed();
    // Set the farm address
    await ShtfiTokenInstance.setFarm(ShtfiFarmInstance.address); // Farm address is the only minter

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
    await ShtfiFarmInstance.add(
      50,
      MockTokenInterface.address,
      currentBlock + 100,
      true
    );
  });
};
