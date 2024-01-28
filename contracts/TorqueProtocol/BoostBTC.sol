// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//  _________  ________  ________  ________  ___  ___  _______
// |\___   ___\\   __  \|\   __  \|\   __  \|\  \|\  \|\  ___ \
// \|___ \  \_\ \  \|\  \ \  \|\  \ \  \|\  \ \  \\\  \ \   __/|
//     \ \  \ \ \  \\\  \ \   _  _\ \  \\\  \ \  \\\  \ \  \_|/__
//      \ \  \ \ \  \\\  \ \  \\  \\ \  \\\  \ \  \\\  \ \  \_|\ \
//       \ \__\ \ \_______\ \__\\ _\\ \_____  \ \_______\ \_______\
//        \|__|  \|_______|\|__|\|__|\|___| \__\|_______|\|_______|

import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./strategies/GMXV2BTC.sol";
import "./strategies/UniswapBTC.sol";

contract BoostBTC is AutomationCompatible, ERC4626, ReentrancyGuard, Ownable {
    
    IERC20 public wbtcToken;
    GMXV2BTC public gmxV2Btc;
    UniswapBTC public uniswapBtc;
    address public treasury;
    address public wBTC;

    uint256 public gmxAllocation;
    uint256 public uniswapAllocation;
    uint256 public lastCompoundTimestamp;
    uint256 public performanceFee;

    constructor(
    string memory _name, 
    string memory _symbol,
    address wBTC,
    address _gmxV2BtcAddress,
    address _uniswapBtcAddress,
    address _treasury
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        wBTC = IERC20(wBTC);
        gmxV2Btc = GMXV2BTC(_gmxV2BtcAddress);
        uniswapBtc = UniswapBTC(_uniswapBtcAddress);
        gmxAllocation = 50;
        uniswapAllocation = 50;
        treasury = _treasury;
    }

    function deposit(uint256 _amount) public override nonReentrant {
        _deposit(_amount);
    }

    function withdraw(uint256 sharesAmount) public override nonReentrant {
        _withdraw(sharesAmount);
    }

    function compoundFees() public override nonReentrant {
        _compoundFees();
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp >= lastCompoundTimestamp + 12 hours);
    }

    function performUpkeep(bytes calldata) external override {
        if ((block.timestamp >= lastCompoundTimestamp + 12 hours)) {
            _compoundFees();
        }
    }

    function depositBTC(uint256 depositAmount) external payable nonReentrant() {
        require(msg.value >= gmxV2Btc.executionFee(), "You must pay GMX v2 execution fee");
        wBTC.transferFrom(msg.sender, address(this), depositAmount);
        uint256 uniswapDepositAmount = depositAmount.mul(uniswapAllocation).div(100);
        uint256 gmxDepositAmount = depositAmount.sub(uniswapDepositAmount);
        wBTC.approve(address(uniswapBtc), uniswapDepositAmount);
        uniswapBtc.deposit(uniswapDepositAmount);

        wBTC.approve(address(gmxV2Btc), gmxDepositAmount);
        gmxV2Btc.deposit{value: gmxV2Btc.executionFee()}(gmxDepositAmount);

        uint256 shares = _convertToShares(depositAmount);
        _mint(msg.sender, shares);
        totalAssetsAmount = totalAssetsAmount.add(depositAmount);
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawBTC(uint256 sharesAmount) external payable nonReentrant() {
        require(msg.value >= gmxV2Btc.executionFee(), "You must pay GMX v2 execution fee");
        uint256 withdrawAmount = _convertToAssets(sharesAmount);
        uint256 uniswapWithdrawAmount = withdrawAmount.mul(uniswapAllocation).div(100);
        uint256 gmxWithdrawAmount = withdrawAmount.sub(uniswapWithdrawAmount);
        _burn(msg.sender, sharesAmount);
        totalAssetsAmount = totalAssetsAmount.sub(withdrawAmount);

        uniswapBtc.withdraw(uniswapWithdrawAmount);
        gmxV2Btc.withdraw{value: gmxV2Btc.executionFee()}(gmxWithdrawAmount);
        uint256 wbtcAmount = wBTC.balanceOf(address(this));
        wBTC.transfer(msg.sender, wbtcAmount);
        payable(msg.sender).transfer(address(this).balance);
    }

    function _compoundFees() internal override {
        // uint256 gmxV2btcBalanceBefore = gmxV2btcStrat.balanceOf(address(this));
        // uint256 uniswapbtcBalanceBefore = uniswapbtcStrat.balanceOf(address(this));
        // uint256 totalBalanceBefore = gmxV2btcBalanceBefore.add(uniswapbtcBalanceBefore);
        // gmxV2btcStrat.withdrawGMX();
        // uniswapbtcStrat.withdrawuniswap();
        // uint256 feeAmount = totalBalanceBefore.mul(performanceFee).div(10000);
        // uint256 treasuryFee = performanceFee.mul(performanceFee).div(100);
        // uint256 gmxV2btcFee = gmxV2btcStrat.balanceOf(address(this));
        // uint256 uniswapbtcFee = uniswapbtcStrat.balanceOf(address(this));
        // wbtcToken.transfer(addresses.treasury, treasuryFee);
        // uint256 totalBalanceAfter = gmxV2btcFee.add(uniswapbtcFee);
        // uint256 gmxV2btcFeeActualPercent = gmxV2btcFee.mul(100).div(totalBalanceAfter);
        // uint256 uniswapbtcFeeActualPercent = uniswapbtcFee.mul(100).div(totalBalanceAfter);
        // gmxV2btcStrat.deposit();
        // uniswapbtcStrat.deposit();
        // lastCompoundTimestamp = block.timestamp;
    }

    function setAllocation() public onlyOwner {
        gmxAllocation = _gmxAllocation;
        uniswapAllocation = _uniswapAllocation;
    }

    function setPerformanceFee(uint256 _performanceFee) public onlyOwner {
        performanceFee = _performanceFee;
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function _checkUpkeep(bytes calldata) external virtual view returns (bool upkeepNeeded, bytes memory);
    
    function _performUpkeep(bytes calldata) external virtual;

    receive() external payable {}
}
