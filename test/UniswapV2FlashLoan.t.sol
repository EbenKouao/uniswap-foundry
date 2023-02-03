// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {UniswapV2FlashLoan} from "../src/UniswapV2FlashLoan.sol";
import {IUniswapV2Factory} from "../src/interfaces/Uniswap.sol";
import {IUniswapV2Pair} from "../src/interfaces/Uniswap.sol";
import {IUniswapV2Router} from "../src/interfaces/Uniswap.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract UniswapV2FlashLoanTest is Test, UniswapV2FlashLoan {
    // Uniswap Flashloan Contract
    UniswapV2FlashLoan public uniswapV2FlashLoan;

    // Uniswap Contract
    IUniswapV2Factory uniswapV2Factory;
    IUniswapV2Pair uniswapPair;
    IUniswapV2Router uniswapV2Router;

    // IERC20 Interface for token contracts
    IERC20 wETHToken;
    IERC20 daiToken;

    // Uniswap V2Factory Address
    // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/router-02
    address private constant ROUTERV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    // Tokens
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    uint256 private constant ETH_WHALE = 200 ether;
    uint256 private constant CONVERT_TO_TOKEN = 1e18;

    function setUp() public {
        // Test Addresses
        address flashLoanUser = address(0x69);
        vm.deal(flashLoanUser, ETH_WHALE);

        // Access existing Uniswap pair contract
        uniswapV2Factory = IUniswapV2Factory(address(FACTORY));

        // Call FlashLoan Receiver
        uniswapV2FlashLoan = new UniswapV2FlashLoan();

        // Uniswap Router
        uniswapV2Router = IUniswapV2Router(address(ROUTERV2));

        // WETH Token
        wETHToken = IERC20(WETH);
        daiToken = IERC20(DAI);
    }

    /// @notice Test can perform a successful flash loan
    function testFlashloanArbitrageTrade() public {
        // transaction deadline limit
        uint256 swapDeadline = block.timestamp;

        // create exchange path
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH(); //Input Token
        path[1] = DAI; // Output Token

        // Swap 100 Eth for DAI in return
        uint256[] memory amounts =
            uniswapV2Router.swapExactETHForTokens{value: 100 ether}(0, path, address(this), swapDeadline);

        // getAmountsOut of the two tokens
        emit Log("amounts[0] WETH in", amounts[0]);
        emit Log("amounts[1] _outputTokenAddressBorrow out", amounts[1]);

        // check balance of wETH
        uint256 wethBalance = wETHToken.balanceOf(address(this));
        uint256 daiBalance = daiToken.balanceOf(address(this));

        emit Log("wethBalance", wethBalance / CONVERT_TO_TOKEN);
        emit Log("daiBalance", daiBalance / CONVERT_TO_TOKEN);

        assertEq(wethBalance, 0, "Contracts WETH Balance should be zero");
        assertEq(daiBalance, amounts[1], "daiBalance from swap from reserves should equal the token balanceOf");

        // approve the tokens - only the swap fee to be transferred
        daiToken.approve(address(uniswapV2FlashLoan), daiBalance);

        uint256 leverageFactor = 2; // borrow n amount more than we have available

        // flashloan a desired amount, so far aw we can pay the 0.3% swap fee (currentBalance * leverage)
        uniswapV2FlashLoan.flashloan(DAI, daiBalance * leverageFactor);
    }
}
