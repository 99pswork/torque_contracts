// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

//  _________  ________  ________  ________  ___  ___  _______
// |\___   ___\\   __  \|\   __  \|\   __  \|\  \|\  \|\  ___ \
// \|___ \  \_\ \  \|\  \ \  \|\  \ \  \|\  \ \  \\\  \ \   __/|
//     \ \  \ \ \  \\\  \ \   _  _\ \  \\\  \ \  \\\  \ \  \_|/__
//      \ \  \ \ \  \\\  \ \  \\  \\ \  \\\  \ \  \\\  \ \  \_|\ \
//       \ \__\ \ \_______\ \__\\ _\\ \_____  \ \_______\ \_______\
//        \|__|  \|_______|\|__|\|__|\|___| \__\|_______|\|_______|

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface AaveLendingPool {
    function repay(
		address asset,
		uint256 amount,
		uint256 rateMode,
		address onBehalfOf
	) external returns (uint256);

    function withdraw(
        address asset, 
        uint256 amount, 
        address to
    ) external returns (uint256);
}

contract AaveWbtcRefinance is Ownable {

    event USDCDeposited(address indexed user, uint256 amount);
    event USDCeDeposited(address indexed user, uint256 amount);
    event WbtcWithdrawn(address indexed user, uint256 amount);
    event AavePoolUpdated(address indexed newAddress);
    event RateModeUpdated(uint256 newRateMode);

    AaveLendingPool aaveLendingPool = AaveLendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    address assetUsdc = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address assetUsdce = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    address assetAaveWbtc = address(0x078f358208685046a11C85e8ad32895DED33A249);
    address assetWbtc = address(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    uint256 rateMode = 2;

    constructor() Ownable(msg.sender) {}
    
    function torqRefinanceUSDC(uint256 usdcAmount, uint256 rWbtcAmount) external {
        depositUSDC(usdcAmount);
        withdrawWBTC(rWbtcAmount);
    }

    function torqRefinanceUSDCe(uint256 usdcAmount, uint256 rWbtcAmount) external {
        depositUSDCe(usdcAmount);
        withdrawWBTC(rWbtcAmount);
    }

    function depositUSDC(uint256 usdcAmount) public {
        require(usdcAmount > 0, "USDC amount must be greater than 0");
        IERC20(assetUsdc).transferFrom(msg.sender, address(this), usdcAmount);
        IERC20(assetUsdc).approve(address(aaveLendingPool), usdcAmount);
        aaveLendingPool.repay(assetUsdc, usdcAmount, rateMode, msg.sender);

        emit USDCDeposited(msg.sender, usdcAmount);
    }

    function depositUSDCe(uint256 usdceAmount) public {
        require(usdceAmount > 0, "USDCe amount must be greater than 0");
        IERC20(assetUsdce).transferFrom(msg.sender, address(this), usdceAmount);
        IERC20(assetUsdce).approve(address(aaveLendingPool), usdceAmount);
        aaveLendingPool.repay(assetUsdce, usdceAmount, rateMode, msg.sender);

        emit USDCeDeposited(msg.sender, usdceAmount);
    }

    function withdrawWBTC(uint256 rWbtcAmount) public {
        require(rWbtcAmount > 0, "rWETH amount must be greater than 0");
        IERC20(assetAaveWbtc).transferFrom(msg.sender, address(this), rWbtcAmount);
        IERC20(assetAaveWbtc).approve(address(aaveLendingPool), rWbtcAmount);
        aaveLendingPool.withdraw(assetWbtc, rWbtcAmount, address(this));

        require(IERC20(assetWbtc).transfer(msg.sender, rWbtcAmount), "Transfer Asset Failed");

        emit WbtcWithdrawn(msg.sender, rWbtcAmount);
    }

    function withdraw(uint256 _amount, address _asset) external onlyOwner {
        require(IERC20(_asset).transfer(msg.sender, _amount), "Transfer Asset Failed");
    }

    function updateAaveLendingPool(address _address) external onlyOwner {
        aaveLendingPool = AaveLendingPool(_address);

        emit AavePoolUpdated(_address);
    }

    function updateRateMode(uint256 _rateMode) external onlyOwner {
        rateMode = _rateMode;

        emit RateModeUpdated(_rateMode);
    }

}
