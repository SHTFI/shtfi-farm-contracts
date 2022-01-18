const { expectRevert, time } = require("@openzeppelin/test-helpers");
const ShtfiToken = artifacts.require("ShtfiToken");
const ShtfiFarm = artifacts.require("ShtfiFarm");
const MockBEP20 = artifacts.require("MockBEP20");

contract("ShtfiFarm", ([alice, bob, carol, dev, minter]) => {
  beforeEach(async () => {
    this.mock = await MockBEP20.new(
      "Mock Token",
      "MOCK",
      "300000000000000000000",
      {
        from: minter,
      }
    );
    await this.mock.transfer(alice, "100000000000000000000", { from: minter });
    await this.mock.transfer(bob, "100000000000000000000", { from: minter });

    this.userInfo = async (_pid, _address) => {
      // get user info for MOCK farm
      const userInfo = await this.farm.userInfo(_pid, _address);
      return {
        amount: userInfo.amount.toString(),
        totalRewards: userInfo.totalRewards.toString(),
        block: await web3.eth.getBlockNumber(),
        farmId: _pid,
        lastClaim: userInfo.lastClaim.toString(),
        pendingReward: (
          await this.farm.pendingReward(_pid, _address)
        ).toString(),
      };
    };

    this.farmInfo = async (pid) => {
      const farm = await this.farm.farmInfo(pid);
      return {
        stakedToken: farm.stakedToken.toString(),
        allocPoint: farm.allocPoint.toString(),
        lastRewardBlock: farm.lastRewardBlock.toString(),
        stakedBalance: farm.stakedBalance.toString(),
        rewardAllocation: farm.rewardAlloc.toString(),
        rewardPerBlock: farm.rewardPerBlock.toString(),
      };
    };

    this.claimRewards = async (_pid, _address) => {
      await this.farm.deposit(_pid, 0, { from: _address });
    };
  });

  it("can open farm", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(
      this.shtfi.address,
      "10000000000000000000",
      150,
      {
        from: minter,
      }
    );
    // Add farm farm with 1 allocation point and make it update
    await this.farm.add(1, this.mock.address, 10, true, { from: minter });
    const farmInfo = await this.farm.farmInfo(1);
    expect(farmInfo.stakedToken.toString()).equal(this.mock.address);
  });

  it("can deposit new farm", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(
      this.shtfi.address,
      "10000000000000000000",
      150,
      {
        from: minter,
      }
    );
    // Set the farm contract to the shtfi token
    this.shtfi.setFarm(this.farm.address, { from: minter });
    // Add the MOCK farm
    await this.farm.add(2, this.mock.address, 100, true, { from: minter });
    // Approve farm to spend 50 MOCK
    await this.mock.approve(this.farm.address, "50", {
      from: minter,
    });
    // Go to shtfi starting block
    await time.advanceBlockTo(100);
    // Deposit 10 MOCK to the farm with ID 1
    await this.farm.deposit(1, "50", { from: minter });
    // Check contract balance;
    expect((await this.mock.balanceOf(this.farm.address)).toString()).equal(
      "50"
    );
  });

  it("can withdraw from farm", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(
      this.shtfi.address,
      "10000000000000000000",
      150,
      {
        from: minter,
      }
    );
    // Set the farm contract to the shtfi token
    this.shtfi.setFarm(this.farm.address, { from: minter });
    // Add the MOCK farm
    await this.farm.add(50, this.mock.address, 120, true, { from: minter });
    // Approve farm to spend 50 MOCK
    await this.mock.approve(this.farm.address, "50000000000000000000", {
      from: minter,
    });
    // Go to starting block
    await time.advanceBlockTo(120);
    // Deposit 10 MOCK to the farm with ID 1
    await this.farm.deposit(1, "50000000000000000000", { from: minter });
    // Check contract balance should be 50
    expect((await this.mock.balanceOf(this.farm.address)).toString()).equal(
      "50000000000000000000"
    );
    // Check our balance should be 50
    expect((await this.mock.balanceOf(minter)).toString()).equal(
      "50000000000000000000"
    );
    // Withdraw
    await this.farm.withdraw(1, "50000000000000000000", { from: minter });
    // Check our balance should be 100
    expect((await this.mock.balanceOf(minter)).toString()).equal(
      "100000000000000000000"
    );
  });

  it("can claim MOCK and deposit SHTFI", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(
      this.shtfi.address,
      "10000000000000000000",
      150,
      {
        from: minter,
      }
    );
    // Set the farm contract on the SHTFI Token contract
    await this.shtfi.setFarm(this.farm.address, { from: minter });
    // Get some MOCK to stake and get SHTFI
    await this.farm.add(50, this.mock.address, 150, true, { from: minter });
    // Farm starts at block 10
    await this.mock.approve(this.farm.address, "10000000000000000000", {
      from: minter,
    });
    // Go to block 100 so we can deposit our shtfi
    await time.advanceBlockTo(150);
    // Deposit some shtfi
    this.farm.deposit(1, "10000000000000000000", { from: minter });
    // Go forward 10 blocks -- SHTFI farm should have 66 shtfi and mock farm should have 33
    await time.advanceBlockTo(159);
    // deposit 0 MOCK to claim our SHTFI reward
    await this.farm.deposit(1, 0, { from: minter });
    // Deposit approve 33 shtfi
    await this.shtfi.approve(this.farm.address, "33000000000000000000", {
      from: minter,
    });
  });

  it("can have multiple stakers", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(
      this.shtfi.address,
      "10000000000000000000",
      200,
      {
        from: minter,
      }
    );
    // Set the farm contract on the SHTFI Token contract
    await this.shtfi.setFarm(this.farm.address, { from: minter });
    // Add the MOCK farm with a weight of 50 (1/3) and starting at block 100 (same as shtfi)
    await this.farm.add(50, this.mock.address, 200, true, { from: minter });
    // Approve farm to spend 50 MOCK

    await this.mock.approve(this.farm.address, "10000000000000000000", {
      from: minter,
    });
    await this.mock.approve(this.farm.address, "10000000000000000000", {
      from: alice,
    });
    await this.mock.approve(this.farm.address, "10000000000000000000", {
      from: bob,
    });

    // Go to block 200
    await time.advanceBlockTo(200);
    // Deposit 10 MOCK to the farm with ID 1
    this.farm.deposit(1, "10000000000000000000", { from: minter });
    this.farm.deposit(1, "10000000000000000000", { from: alice });
    this.farm.deposit(1, "10000000000000000000", { from: bob });
    // fast forward to block 209 -- 10 mintable blocks passed so 100 SHTFI minted
    await time.advanceBlockTo(211);
    // Harvest SHTFI
    await this.farm.deposit(1, 0, { from: minter });
    await this.farm.deposit(1, 0, { from: alice });
    await this.farm.deposit(1, 0, { from: bob });
    // All users share 1/3 of the farm which should have a balance of 33
    // This means each staker should receive 11 tokens
    expect((await this.shtfi.balanceOf(minter)).toString()).equal(
      "11111111111111111110"
    );
    expect((await this.shtfi.balanceOf(alice)).toString()).equal(
      "11111111111111111110"
    );
    expect((await this.shtfi.balanceOf(bob)).toString()).equal(
      "11111111111111111110"
    );
  });

  it("cant double claim", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(this.shtfi.address, "10", 250, {
      from: minter,
    });
    // Set the farm contract on the SHTFI Token contract
    await this.shtfi.setFarm(this.farm.address, { from: minter });
    // Get some MOCK to stake and get SHTFI
    await this.farm.add(50, this.mock.address, 250, true, { from: minter });
    // Farm starts at block 10
    await this.mock.approve(this.farm.address, "50", {
      from: minter,
    });
    // Go to block 100 so we can deposit our shtfi
    await time.advanceBlockTo(250);
    // Deposit some shtfi
    await this.farm.deposit(1, "50", { from: minter });
    // Go forward 10 blocks -- SHTFI farm should have 66 shtfi and mock farm should have 33
    await time.advanceBlockTo(261);
    // Withdraw our stake
    await this.farm.withdraw(1, "50", { from: minter });
    // Check shtfi has been received and mock returned
    expect((await this.shtfi.balanceOf(minter)).toString()).equal("33");
    expect((await this.mock.balanceOf(minter)).toString()).equal(
      "100000000000000000000"
    );

    // Try and claim again
    await this.farm.deposit(1, 0, { from: minter });
    // Balances should remain the same
    expect((await this.shtfi.balanceOf(minter)).toString()).equal("33");
    expect((await this.mock.balanceOf(minter)).toString()).equal(
      "100000000000000000000"
    );
    // Try and claim again
    await this.farm.deposit(1, 0, { from: minter });
    // Balances should remain the same
    expect((await this.shtfi.balanceOf(minter)).toString()).equal("33");
    expect((await this.mock.balanceOf(minter)).toString()).equal(
      "100000000000000000000"
    );
  });

  it("reset claim after withdraw", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(this.shtfi.address, "10", 300, {
      from: minter,
    });
    // Set the farm contract on the SHTFI Token contract
    await this.shtfi.setFarm(this.farm.address, { from: minter });
    // Get some MOCK to stake and get SHTFI
    await this.farm.add(50, this.mock.address, 300, true, { from: minter });
    // Farm starts at block 300
    await this.mock.approve(this.farm.address, "500", {
      from: minter,
    });

    // Go to block 300 so we can deposit our shtfi
    await time.advanceBlockTo(300);
    // Deposit some shtfi
    await this.farm.deposit(1, "50", { from: minter });
    // Go forward 10 blocks -- SHTFI farm should have 66 shtfi and mock farm should have 33
    await time.advanceBlockTo(311);

    // Withdraw our stake
    await this.farm.withdraw(1, "50", { from: minter });

    let user = await this.userInfo(1, minter);

    expect(user.lastClaim).equal("0");
    expect(user.pendingReward).equal("0");

    // go to block 400
    await time.advanceBlockTo(400);
    // Deposit our mock again
    await this.farm.deposit(1, "50", { from: minter });
    // last claim should be block 401
    user = await this.userInfo(1, minter);
    expect(user.lastClaim).equal("401");

    // go forward 10 blocks
    await time.advanceBlockTo(412);
    // User should have 33 pending rewards
    user = await this.userInfo(1, minter);
    expect(user.pendingReward).equal("33");

    // Claim our rewards -- will be 36 claimed (1 block passed since checking pending shtfi)
    // total claimed will now be 69 -- hey hey
    await this.farm.deposit(1, 0, { from: minter });
    user = await this.userInfo(1, minter);
    expect(user.totalRewards).equal("69");
    expect((await this.shtfi.balanceOf(minter)).toString()).equal("69");
  });

  it("cant deposit when locked", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(this.shtfi.address, "2", 500, {
      from: minter,
    });
    // Set the farm contract on the SHTFI Token contract
    await this.shtfi.setFarm(this.farm.address, { from: minter });
    // Get some MOCK to stake and get SHTFI
    await this.farm.add(50, this.mock.address, 500, true, { from: minter });
    // Farm starts at block 300
    await this.mock.approve(this.farm.address, "500", {
      from: minter,
    });

    // Go to block 300 so we can deposit our shtfi
    await time.advanceBlockTo(500);
    // Deposit some shtfi
    await this.farm.deposit(1, "50", { from: minter });
    // Lock the farm contract
    await this.farm.endMining({ from: minter });
    try {
      // Deposit should now fail
      await this.farm.deposit(1, "50", { from: minter });
    } catch (error) {
      expect(/ERROR\: FARMING PAUSED/g.test(error.message)).equal(true);
    }
  });

  it("can withdraw and claim rewards when locked", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(
      this.shtfi.address,
      "200000000000000000",
      550,
      {
        from: minter,
      }
    );
    // Set the farm contract on the SHTFI Token contract
    await this.shtfi.setFarm(this.farm.address, { from: minter });
    // Get some MOCK to stake and get SHTFI
    await this.farm.add(50, this.mock.address, 550, true, { from: minter });
    // Farm starts at block 300
    await this.mock.approve(this.farm.address, "500", {
      from: minter,
    });

    // Go to block 300 so we can deposit our shtfi
    await time.advanceBlockTo(550);
    // Deposit some shtfi
    await this.farm.deposit(1, "50", { from: minter });
    // Go to block 300 so we can deposit our shtfi
    await time.advanceBlockTo(559);
    // Lock the farm contract
    await this.farm.endMining({ from: minter });
    // Withdraw user's liquidity
    await this.farm.withdraw(1, "50", { from: minter });
    expect(parseInt((await this.shtfi.balanceOf(minter)).toString())).equal(
      666666666666666660
    );
  });

  it("can get farm id", async () => {
    // Create SHTFI Token
    this.shtfi = await ShtfiToken.new({ from: minter });
    // Redeploy the farm so we can ensure it is on the correct block.
    this.farm = await ShtfiFarm.new(
      this.shtfi.address,
      "200000000000000000",
      550,
      {
        from: minter,
      }
    );
    // Set the farm contract on the SHTFI Token contract
    await this.shtfi.setFarm(this.farm.address, { from: minter });
    // Get some MOCK to stake and get SHTFI
    await this.farm.add(50, this.mock.address, 550, true, { from: minter });
    // Farm starts at block 300
    await this.mock.approve(this.farm.address, "500", {
      from: minter,
    });

    const shtfiFarmId = (
      await this.farm.getFarmId(this.shtfi.address)
    ).toString();
    const mockFarmId = (
      await this.farm.getFarmId(this.mock.address)
    ).toString();

    expect(shtfiFarmId).equal("0");
    expect(mockFarmId).equal("1");
  });
});
