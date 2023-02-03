// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {UniswapV2RouterHelpers} from "../src/UniswapV2RouterHelpers.sol";
import {IUniswapV2Factory} from "../src/interfaces/Uniswap.sol";
import {IUniswapV2Pair} from "../src/interfaces/Uniswap.sol";
import {IUniswapV2Router} from "../src/interfaces/Uniswap.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {Errors} from "../src/utils/Errors.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapV2RouterHelpersTest is Test {
    using SafeERC20 for IERC20;

    // Uniswap Flashloan Contract
    UniswapV2RouterHelpers public uniswapV2RouterHelpers;

    // Uniswap Contract
    IUniswapV2Factory uniswapV2Factory;
    IUniswapV2Pair uniswapPair;
    IUniswapV2Router uniswapV2Router;

    // IERC20 Interface for token contract interaction
    IERC20 wethToken;
    IERC20 daiToken;

    // Uniswap V2Factory Address
    //https://docs.uniswap.org/contracts/v2/reference/smart-contracts/router-02
    address private constant ROUTERV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    // Tokens
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    uint256 private constant ETH_WHALE = 200 ether;
    uint256 private constant CONVERT_TO_TOKEN = 1e18;

    address user1 = address(0x69);

    function setUp() public {
        // Test Addresses
        vm.deal(user1, ETH_WHALE);

        // Uniswap Router Interaction
        uniswapV2Router = IUniswapV2Router(address(ROUTERV2));
        uniswapV2RouterHelpers = new UniswapV2RouterHelpers();

        wethToken = IERC20(WETH);
        daiToken = IERC20(DAI);
    }

    /// @notice Test that can swap ETH for DAI Tokens
    function testSwapEthForDAITokens() public {
        vm.startPrank(address(user1));

        uint256 balanceBefore = address(user1).balance;
        uint256 ethToSwap = 2 ether;

        uint256[] memory amounts = uniswapV2RouterHelpers.swapEthForDAI{value: ethToSwap}();

        uint256 wethBalance = wethToken.balanceOf(address(user1));
        uint256 daiBalance = daiToken.balanceOf(address(user1));

        assertEq(daiBalance, amounts[1], "Amount Out via swap from reserves should equal the token balanceOf");

        vm.stopPrank();
    }

    /// @notice Test that can swap ETH for any Token
    function testSwapEthForAnyToken() public {
        vm.startPrank(address(user1));

        uint256 balanceBefore = address(user1).balance;
        uint256 ethToSwap = 2 ether;

        uint256[] memory amounts = uniswapV2RouterHelpers.SwapEthForAnyToken{value: ethToSwap}(DAI);

        uint256 outputTokenBalance = IERC20(DAI).balanceOf(address(user1));
        assertEq(outputTokenBalance, amounts[1], "Amount Out via swap from reserves should equal the token balanceOf");

        vm.stopPrank();
    }

    /// @notice Test that token pair/ exchange must be valid
    function testCannotSwapEthForInvalidTokenPair() public {
        vm.startPrank(address(user1));

        uint256 balanceBefore = address(user1).balance;
        uint256 ethToSwap = 2 ether;

        vm.expectRevert(Errors.InvalidTokenPair.selector);
        uint256[] memory amounts = uniswapV2RouterHelpers.SwapEthForAnyToken{value: ethToSwap}(WETH);

        vm.stopPrank();
    }

    /// @notice Test can swap ETh for WETH (directly with WETH contract)
    function testCanSwapEthForWETH() public {
        vm.startPrank(address(user1));

        uint256 ethToSwap = 2 ether;

        uniswapV2RouterHelpers.convertETHtoWETH{value: ethToSwap}();
        uint256 wethBalance = IERC20(WETH).balanceOf(address(user1)); // How to even check from hex to toNumber/ balance Of

        assertEq(wethBalance, ethToSwap, "WETH Returned should be the same as ETH Deposited");

        vm.stopPrank();
    }

    /// @notice Test can swap WETH for any token
    function testCanSwapWETHForAnyToken() public {
        vm.startPrank(address(user1));
        uint256 ethToSwap = 2 ether;

        uniswapV2RouterHelpers.convertETHtoWETH{value: ethToSwap}();
        uint256 wethBalance = IERC20(WETH).balanceOf(address(user1)); // wEth Balance of user

        // Convert ETH -> WETH
        IERC20(address(WETH)).transfer(address(uniswapV2RouterHelpers), wethBalance);
        uint256[] memory amounts = uniswapV2RouterHelpers.swapWETHForAnyToken(DAI, 1e18);

        uint256 outputTokenBalance = IERC20(DAI).balanceOf(address(user1)); // How to even check from hex to toNumber/ balance Of
        assertEq(outputTokenBalance, amounts[1], "Amount Out via swap from reserves should equal the token balanceOf");

        vm.stopPrank();
    }

    /// @notice Test can swap WETH for any token (via speified path/ exchange route)
    function testCanSwapWETHForAnyTokenAnyPath() public {
        vm.startPrank(address(user1));
        uint256 ethToSwap = 2 ether;

        // create exchange path
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;

        uniswapV2RouterHelpers.convertETHtoWETH{value: ethToSwap}();
        uint256 wethBalance = IERC20(WETH).balanceOf(address(user1)); // wEth Balance of user

        // You'll need to send tokens back that you have as WETH
        IERC20(address(WETH)).transfer(address(uniswapV2RouterHelpers), wethBalance);
        uint256[] memory amounts = uniswapV2RouterHelpers.swapWETHForAnyTokenAnyPath(DAI, 1e18, path);

        uint256 outputTokenBalance = IERC20(DAI).balanceOf(address(user1)); // How to even check from hex to toNumber/ balance Of
        assertEq(outputTokenBalance, amounts[1], "Amount Out via swap from reserves should equal the token balanceOf");

        vm.stopPrank();
    }
}
