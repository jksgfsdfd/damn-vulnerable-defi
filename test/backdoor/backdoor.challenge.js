const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Backdoor", function () {
  let deployer, users, player;
  let masterCopy, walletFactory, token, walletRegistry;

  const AMOUNT_TOKENS_DISTRIBUTED = 40n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, alice, bob, charlie, david, player] = await ethers.getSigners();
    users = [alice.address, bob.address, charlie.address, david.address];

    // Deploy Gnosis Safe master copy and factory contracts
    masterCopy = await (
      await ethers.getContractFactory("GnosisSafe", deployer)
    ).deploy();
    walletFactory = await (
      await ethers.getContractFactory("GnosisSafeProxyFactory", deployer)
    ).deploy();
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();

    // Deploy the registry
    walletRegistry = await (
      await ethers.getContractFactory("WalletRegistry", deployer)
    ).deploy(masterCopy.address, walletFactory.address, token.address, users);
    expect(await walletRegistry.owner()).to.eq(deployer.address);

    for (let i = 0; i < users.length; i++) {
      // Users are registered as beneficiaries
      expect(await walletRegistry.beneficiaries(users[i])).to.be.true;

      // User cannot add beneficiaries
      await expect(
        walletRegistry
          .connect(await ethers.getSigner(users[i]))
          .addBeneficiary(users[i])
      ).to.be.revertedWithCustomError(walletRegistry, "Unauthorized");
    }

    // Transfer tokens to be distributed to the registry
    await token.transfer(walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */
    // create safe wallets with the beneficiaries as the owner address. and check if we are able to retrieve the tokens from such a safe wallet
    // we have to call the createProxyWithCallback function of the safeProxyFactory. the salt can be incremented for each user's contract. before the callback is invoked we have to set the owner address to be that of alice,bob etc. for this we have to see how the initialzier param is used.
    // to be able to retrieve the tokens, we must be able to setup something in the safe wallet that gives us the access and we only have the setup call that we can make. the _getFallback manager wrongs reads 32 words from the fallback manager slot. but i don't know if this can be used to exploit since i don't know how abi.decode will work for unmatched sizes. no this cannot be used since abi.decode will decode as usual
    // the safe contract makes a delegateCall with the to and data parameters. this must be enough. since we can do delegate call to any address we can make the contract execute any logic we want. hence we can set approval for ourselves in the token contract and receive the tokens.
    const attacker = await (
      await ethers.getContractFactory("BackdoorAttackerInvoker", player)
    ).deploy(
      walletFactory.address,
      masterCopy.address,
      walletRegistry.address,
      users,
      token.address,
      10n * 10n ** 18n
    );
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Player must have used a single transaction
    expect(await ethers.provider.getTransactionCount(player.address)).to.eq(1);

    for (let i = 0; i < users.length; i++) {
      let wallet = await walletRegistry.wallets(users[i]);

      // User must have registered a wallet
      expect(wallet).to.not.eq(
        ethers.constants.AddressZero,
        "User did not register a wallet"
      );

      // User is no longer registered as a beneficiary
      expect(await walletRegistry.beneficiaries(users[i])).to.be.false;
    }

    // Player must own all tokens
    expect(await token.balanceOf(player.address)).to.eq(
      AMOUNT_TOKENS_DISTRIBUTED
    );
  });
});
