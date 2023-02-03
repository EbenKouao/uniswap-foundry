// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Factory} from "./interfaces/Uniswap.sol";
import {IUniswapV2Router} from "./interfaces/Uniswap.sol";
import {IUniswapV2Pair} from "./interfaces/Uniswap.sol";
import {Errors} from "./utils/Errors.sol";
import {IWETH} from "./interfaces/IWETH.sol";

// Custom Router Helpers to interact with UniswapV2
contract UniswapV2RouterHelpers {
    using SafeERC20 for IERC20;

    address public owner;

    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Uniswap V2 factory
    address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant ROUTERV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 private constant CONVERT_TO_TOKEN = 1e18;

    // IERC20 Interface for token contract interaction
    IERC20 wETHToken;
    IERC20 daiToken;

    IUniswapV2Factory uniswapV2Factory;
    IUniswapV2Router uniswapV2Router;
    IUniswapV2Pair uniswapPair;

    // Emit logs for internal tests (contract optimized for demo purposes)
    event Log(string message, uint256 val);

    constructor() {
        owner = msg.sender;
        uniswapV2Router = IUniswapV2Router(ROUTERV2);
        uniswapPair = IUniswapV2Pair(FACTORY);
        uniswapV2Factory = IUniswapV2Factory(address(FACTORY));

        // Token Instances
        wETHToken = IERC20(WETH);
        daiToken = IERC20(DAI);
    }

    /// @notice Swap Exact amount of ETH for DAI Tokens
    /// @return amounts Amount of tokenA/tokenB
    function swapEthForDAI() public payable returns (uint256[] memory amounts) {
        if (msg.value == 0) revert Errors.InvalidAmount();

        // transaction deadline limit
        uint256 swapDeadline = block.timestamp;

        // create exchange path
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH(); //Input Token
        path[1] = DAI; // Output Token

        // should check if pair exists
        if (uniswapV2Factory.getPair(uniswapV2Router.WETH(), DAI) == address(0)) {
            revert Errors.InvalidTokenPair();
        }

        // Swap Eth for DAI
        amounts = uniswapV2Router.swapExactETHForTokens{value: msg.value}(0, path, address(this), swapDeadline);

        emit Log("amount[0] WETH in", amounts[0]);
        emit Log("amount[1] DAI out", amounts[1]);

        // check balance of WETH
        uint256 wethBalance = wETHToken.balanceOf(address(this));
        uint256 daiBalance = daiToken.balanceOf(address(this)); // How to even check from hex to toNumber/ balance Of

        emit Log("WETH Balance", wethBalance / CONVERT_TO_TOKEN);
        emit Log("DAI Balance", daiBalance / CONVERT_TO_TOKEN);

        // send DAI balance to msg.sender
        IERC20(daiToken).safeTransfer(msg.sender, daiBalance);
    }

    /// @notice Swap Exact amount of Eth for any token out. (Token Pair/ Exchange - must already exist)
    /// @param _outputTokenAddress The desired token contract address
    /// @return amounts Amount of tokenA/tokenB
    function SwapEthForAnyToken(address _outputTokenAddress) public payable returns (uint256[] memory amounts) {
        if (msg.value == 0) revert Errors.InvalidAmount();

        // transaction deadline limit
        uint256 swapDeadline = block.timestamp;

        // create exchange path
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH(); //Input Token
        path[1] = _outputTokenAddress; // Output Token

        // should check if pair exists
        if (uniswapV2Factory.getPair(uniswapV2Router.WETH(), _outputTokenAddress) == address(0)) {
            revert Errors.InvalidTokenPair();
        }

        // Swap ETH/(WETH) for any tokens
        amounts = uniswapV2Router.swapExactETHForTokens{value: msg.value}(0, path, address(this), swapDeadline);

        emit Log("amount[0] WETH in", amounts[0]);
        emit Log("amount[1] targetAddress out", amounts[1]);

        // check balance
        uint256 wethBalance = IERC20(address(uniswapV2Router.WETH())).balanceOf(address(this));
        uint256 targetBalance = IERC20(address(_outputTokenAddress)).balanceOf(address(this)); // How to even check from hex to toNumber/ balance Of

        emit Log("WETH Balance", wethBalance / CONVERT_TO_TOKEN);
        emit Log("targetBalance", targetBalance / CONVERT_TO_TOKEN);

        // send amountOut to msg.sender
        IERC20(address(_outputTokenAddress)).safeTransfer(msg.sender, targetBalance);
    }

    /// @notice Convert ETH to WETH via Wrapper Contract
    // Fund Wallet with ETH -> I.e ETHtoWETH
    function convertETHtoWETH() public payable {
        if (msg.value == 0) revert Errors.InvalidAmount();

        IWETH(address(WETH)).deposit{value: msg.value}();
        uint256 wethDeposited = IERC20(address(WETH)).balanceOf(address(this));

        assert(IWETH(WETH).transfer(msg.sender, wethDeposited));
        uint256 wethTransfered = IERC20(address(WETH)).balanceOf(msg.sender);
        emit Log("WETH Transfered", wethTransfered / CONVERT_TO_TOKEN);
    }

    /// @notice Swap Exact amount of WETH for any token out. (Token Pair/ Exchange must already exist)
    /// @param _outputTokenAddress The desired token contract address
    /// @param _amount the token amount desired
    function swapWETHForAnyToken(address _outputTokenAddress, uint256 _amount)
        public
        returns (uint256[] memory amounts)
    {
        // transaction deadline limit
        uint256 txnDeadline = block.timestamp;
        IERC20(address(uniswapV2Router.WETH())).approve(address(uniswapV2Router), _amount);

        // create exchange path
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = _outputTokenAddress;

        uint256 wethBalance = IERC20(address(uniswapV2Router.WETH())).balanceOf(address(this));
        emit Log("wethBalance", wethBalance / CONVERT_TO_TOKEN);

        amounts = uniswapV2Router.swapExactTokensForTokens(_amount, 0, path, address(this), txnDeadline);
        emit Log("targetToken Amount Out", amounts[1] / CONVERT_TO_TOKEN);

        // transfer back to user
        IERC20(daiToken).safeTransfer(msg.sender, amounts[1]);
    }

    /// @notice Swap Exact amount of WETH for any token out through a desired path e.g. DAI -> WETH -> wBTC. (Token Pair/ Exchange must already exist)
    /// @param _outputTokenAddress The desired token contract address
    /// @param _amount the token amount desired
    /// @param _path An array of token addresses
    /// @return amounts Amount of tokenA/tokenB
    function swapWETHForAnyTokenAnyPath(address _outputTokenAddress, uint256 _amount, address[] calldata _path)
        public
        returns (uint256[] memory amounts)
    {
        // transaction deadline limit
        uint256 txnDeadline = block.timestamp;

        IERC20(address(uniswapV2Router.WETH())).approve(address(uniswapV2Router), _amount);

        uint256 wethBalance = IERC20(address(uniswapV2Router.WETH())).balanceOf(address(this));
        emit Log("WETH Balance", wethBalance / CONVERT_TO_TOKEN);

        amounts = uniswapV2Router.swapExactTokensForTokens(_amount, 0, _path, address(this), txnDeadline);
        emit Log("targetToken Amount Out", amounts[1] / CONVERT_TO_TOKEN);

        // transfer back to user
        IERC20(daiToken).safeTransfer(msg.sender, amounts[1]);
    }

    /// @notice SwapWETHForTokenWithFeeOnTransfer
    /// @param _outputTokenAddress The desired token contract address
    /// @param _amount the token amount desired
    //  e.g. swap for compound token / AAVE and test to sure a non-fee token reverts
    function swapWETHForAnyTokenWithFeeOnTransfer(address _outputTokenAddress, uint256 _amount) public {}

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }
}
