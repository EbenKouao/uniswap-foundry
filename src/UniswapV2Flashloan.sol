// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Errors} from "./utils/Errors.sol";
import {IUniswapV2Pair} from "../src/interfaces/Uniswap.sol";
import {IUniswapV2Factory} from "../src/interfaces/Uniswap.sol";
import {IUniswapV2Router} from "../src/interfaces/Uniswap.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

contract UniswapV2FlashLoan is IUniswapV2Callee, Ownable {
    using SafeERC20 for IERC20;

    uint256 private constant CONVERT_TO_TOKEN = 1e18;

    // Uniswap V2 factory
    address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant ROUTERV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Emit logs for internal tests (contract optimized for demo purposes)
    event Log(string message, uint256 val);
    event Log_address(string message, address addr);

    /// @notice Call Flashloan via UniswapV2 Swap
    function flashloan(address _outputTokenAddressBorrow, uint256 _amount) external onlyOwner {
        address pair = IUniswapV2Factory(FACTORY).getPair(WETH, _outputTokenAddressBorrow);
        if (pair == address(0)) revert Errors.InvalidTokenPair();

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        // getPair and sort for token0 being the desired token to borrow
        uint256 amount0Out = _outputTokenAddressBorrow == token0 ? _amount : 0;
        uint256 amount1Out = _outputTokenAddressBorrow == token1 ? _amount : 0;

        // need to pass data, as data.length > 0 is required to trigger uniswapV2Call
        bytes memory data = abi.encode(_outputTokenAddressBorrow, _amount, msg.sender);

        // Provided data, we can now take a flash loan irrespecitve of our balance
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    /// @notice Pair contract callback via uniswapV2Call (flashloan)
    /// Borrow as many tokens so far as we can payback the swap fee
    function uniswapV2Call(address _to, uint256 _amount0, uint256 _amount1, bytes calldata _data) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0(); //address of token0
        address token1 = IUniswapV2Pair(msg.sender).token1(); // address of token1
        address pair = IUniswapV2Factory(FACTORY).getPair(token0, token1); //getPair address

        if (msg.sender != pair) revert Errors.InvalidTokenPair();
        if (_to != address(this)) revert Errors.InvalidRecipient();

        // Amount from desired token address
        (address _outputTokenAddressBorrow, uint256 _amount, address _borrower) =
            abi.decode(_data, (address, uint256, address));

        // Uniswap 0.3% Swap Fee
        uint256 fee = ((_amount * 3) / 997) + 1;
        uint256 amountToRepay = _amount + fee;

        uint256 balanceBefore = IERC20(_outputTokenAddressBorrow).balanceOf(address(this));

        // Logging - Dev Only (1e18 sclaed)
        emit Log("Borrow Amount (via Flashloan): ", _amount / CONVERT_TO_TOKEN);
        emit Log("Amount Received (amount0)", _amount0 / CONVERT_TO_TOKEN);

        emit Log("Swap Fee (0.3%)", fee / CONVERT_TO_TOKEN);
        emit Log("Amount to Repay (Amount + Swap Fee)", amountToRepay / CONVERT_TO_TOKEN);

        // Start Trade Strategy
        _tradeStrategy(_outputTokenAddressBorrow, _amount);
        // End Trade Stratergy

        // Fund the Flashloan a swap fee before payback to Pair/Pool
        IERC20(_outputTokenAddressBorrow).safeTransferFrom(_borrower, address(this), fee);

        // Payback amount + fee
        IERC20(_outputTokenAddressBorrow).safeTransfer(pair, amountToRepay);

        uint256 balanceAfter = IERC20(_outputTokenAddressBorrow).balanceOf(address(this));
        emit Log("amount in DAI after: ", balanceAfter / CONVERT_TO_TOKEN);
    }

    /// @notice The Trade Strategy to Implementent - we must make profit to complete the flashloan
    function _tradeStrategy(address _outputTokenAddressBorrow, uint256 _amount) internal {
        // The Trade Strategy
        uint256 balanceAfterTrade = IERC20(_outputTokenAddressBorrow).balanceOf(address(this));
        uint256 profits = balanceAfterTrade - _amount;

        emit Log("Profits after trade (in wei)", profits);

        // check if made profit (for demo purposes, realistically checks to be made off chain before perfoming a flashloan)
        // if (profits == 0) revert Errors.NoProfits();
    }

    function getSpotPrice(address _pair, uint256 _amount) public returns (uint256 quotePrice) {
        if (_amount == 0) revert Errors.InvalidAmount();
        if (_pair == address(0)) revert Errors.InvalidRecipient();

        // amount to Repay comes from the token we borrowed
        (uint256 reserveA, uint256 reserveB,) = IUniswapV2Pair(_pair).getReserves();
        // Logging - Dev Only
        emit Log("ReserveA", reserveA / CONVERT_TO_TOKEN);
        emit Log("ReserveB", reserveB / CONVERT_TO_TOKEN);

        // get price of token based on the current reserves (if no fees are involved)
        uint256 quotePrice = IUniswapV2Router(address(ROUTERV2)).quote(_amount, reserveB, reserveB);
        emit Log("Price Fee", quotePrice);
    }
}
