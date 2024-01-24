// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//  _________  ________  ________  ________  ___  ___  _______
// |\___   ___\\   __  \|\   __  \|\   __  \|\  \|\  \|\  ___ \
// \|___ \  \_\ \  \|\  \ \  \|\  \ \  \|\  \ \  \\\  \ \   __/|
//     \ \  \ \ \  \\\  \ \   _  _\ \  \\\  \ \  \\\  \ \  \_|/__
//      \ \  \ \ \  \\\  \ \  \\  \\ \  \\\  \ \  \\\  \ \  \_|\ \
//       \ \__\ \ \_______\ \__\\ _\\ \_____  \ \_______\ \_______\
//        \|__|  \|_______|\|__|\|__|\|___| \__\|_______|\|_______|

import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IWETH9.sol";
import "./strategies/GMXV2ETH.sol";
import "./strategies/StargateETH.sol";

contract BoostETH is AutomationCompatible, Ownable, ReentrancyGuard, ERC20{
    using SafeMath for uint256;
    using Math for uint256;

    IWETH9 public weth;
    GMXV2ETH public gmxV2ETH;
    StargateETH public stargateETH;
    address public treasury;

    uint256 public gmxAllocation;
    uint256 public stargateAllocation;
    uint256 public lastCompoundTimestamp;
    uint256 public performanceFee;
    
    uint256 public totalAssetsAmount;

    constructor(string memory _name, string memory _symbol, address payable weth_, address gmxV2ETH_, address stargateETH_, address treasury_) ERC20(_name, _symbol){
        weth = IWETH9(weth_);
        gmxV2ETH = GMXV2ETH(gmxV2ETH_);
        stargateETH = StargateETH(stargateETH_);
        treasury = treasury_;
        gmxAllocation = 50;
        stargateAllocation = 50;
        performanceFee = 10;
        lastCompoundTimestamp = block.timestamp;
        totalAssetsAmount = 0;
    }

    function depositETH(uint256 depositAmount) external payable nonReentrant() {
        weth.transferFrom(msg.sender, address(this), depositAmount);
        uint256 stargateDepositAmount = depositAmount.mul(stargateAllocation).div(100);
        uint256 gmxDepositAmount = depositAmount.sub(stargateDepositAmount);
        weth.approve(address(stargateETH), stargateDepositAmount);
        stargateETH.deposit(stargateDepositAmount);

        weth.approve(address(gmxV2ETH), gmxDepositAmount);
        gmxV2ETH.deposit(gmxDepositAmount);

        uint256 shares = _convertToShares(depositAmount);
        _mint(msg.sender, shares);
        totalAssetsAmount = totalAssetsAmount.add(depositAmount);
    }

    function withdrawETH(uint256 sharesAmount) external nonReentrant() {
        uint256 withdrawAmount = _convertToAssets(sharesAmount);
        uint256 stargateWithdrawAmount = withdrawAmount.mul(stargateAllocation).div(100);
        uint256 gmxWithdrawAmount = withdrawAmount.sub(stargateWithdrawAmount);
        _burn(msg.sender, sharesAmount);
        totalAssetsAmount = totalAssetsAmount.sub(withdrawAmount);

        stargateETH.withdraw(stargateWithdrawAmount);
        gmxV2ETH.withdraw(gmxWithdrawAmount);
        uint256 wethAmount = weth.balanceOf(address(this));
        weth.transfer(msg.sender, wethAmount);
    }

    function totalAssets() public view returns (uint256) {
        return totalAssetsAmount;
    }

    function _convertToShares(uint256 assets) internal view returns (uint256) {
        uint256 supply = totalSupply();
        return (assets==0 || supply==0) ? assets : assets.mulDiv(supply, totalAssets(), Math.Rounding.Down);
    }

    function _convertToAssets(uint256 shares) internal view returns (uint256){
        uint256 supply = totalSupply();
        return (supply==0) ? shares : shares.mulDiv(totalAssets(), supply, Math.Rounding.Down);
    }

    function compoundFees() external nonReentrant(){
        _compoundFees();
    }

    function _compoundFees() internal {
        uint256 prevWethAmount = weth.balanceOf(address(this));
        stargateETH.compound();
        gmxV2ETH.compound();
        uint256 postWethAmount = weth.balanceOf(address(this));
        uint256 treasuryFee = (postWethAmount - prevWethAmount).mul(performanceFee).div(100);
        weth.withdraw(treasuryFee);
        payable(treasury).transfer(treasuryFee);
        uint256 wethAmount = postWethAmount - treasuryFee;
        uint256 stargateDepositAmount = wethAmount.mul(stargateAllocation).div(100);
        uint256 gmxDepositAmount = wethAmount.sub(stargateDepositAmount);
        totalAssetsAmount = totalAssetsAmount + wethAmount;
        weth.approve(address(stargateETH), stargateDepositAmount);
        stargateETH.deposit(stargateDepositAmount);
        weth.approve(address(gmxV2ETH), gmxDepositAmount);
        gmxV2ETH.deposit(gmxDepositAmount);
        lastCompoundTimestamp = block.timestamp;
    }

    function setAllocation(uint256 _stargateAllocation, uint256 _gmxAllocation) public onlyOwner {
        require((_stargateAllocation + _gmxAllocation)==100, "All allocation should be 100");
        gmxAllocation = _gmxAllocation;
        stargateAllocation = _stargateAllocation;
    }

    function setPerformanceFee(uint256 _performanceFee) public onlyOwner {
        performanceFee = _performanceFee;
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp >= lastCompoundTimestamp + 12 hours);
    }

    function performUpkeep(bytes calldata) external override {
        if ((block.timestamp >= lastCompoundTimestamp + 12 hours)) {
            _compoundFees();
        }
    }

    receive() external payable {}
}