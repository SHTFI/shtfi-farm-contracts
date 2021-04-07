const { expectRevert, time } = require("@openzeppelin/test-helpers");
const { assert } = require("chai");
const ShitToken = artifacts.require("ShitToken");

contract("ShitToken", ([alice, bob, carol, dev, minter]) => {
  beforeEach(async () => {
    this.shit = await ShitToken.new({ from: minter });
  });
});
