pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { DSMath } from "../../common/math.sol";
import { Stores } from "../../common/stores-mainnet.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Variables } from "./variables.sol";

import { 
    AaveLendingPoolProviderInterface,
    AaveDataProviderInterface,
    AaveInterface,
    ATokenInterface,
    StateSenderInterface,
    AavePriceOracle,
    ChainLinkInterface,
    ReserveConfigurationMap
} from "./interfaces.sol";

abstract contract Helpers is DSMath, Stores, Variables {
    using SafeERC20 for IERC20;

    /**
     * @dev Aave reserve configuration bit masks
     */
    // uint256 constant LIQUIDATION_THRESHOLD_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF;
    // uint256 constant DECIMALS_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF;
    // uint256 constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    // uint256 constant RESERVE_DECIMALS_START_BIT_POSITION = 48;

    // /**
    //  * @dev Additional math helpers
    //  */
    // uint256 constant PERCENTAGE_FACTOR = 1e4; //percentage plus two decimals
    // uint256 constant HALF_PERCENT = PERCENTAGE_FACTOR / 2;

    // function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256) {
    //     if (value == 0 || percentage == 0) {
    //         return 0;
    //     }

    //     require(
    //         value <= (type(uint256).max - HALF_PERCENT) / percentage,
    //         "percent-mul-overflow"
    //     );

    //     return (value * percentage + HALF_PERCENT) / PERCENTAGE_FACTOR;
    // }

    function _paybackBehalfOne(AaveInterface aave, address token, uint amt, uint rateMode, address user) private {
        address _token = token == ethAddr ? wethAddr : token;
        aave.repay(_token, amt, rateMode, user);
    }

    function _PaybackStable(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts,
        address user
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                _paybackBehalfOne(aave, tokens[i], amts[i], 1, user);
            }
        }
    }

    function _PaybackVariable(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts,
        address user
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                _paybackBehalfOne(aave, tokens[i], amts[i], 2, user);
            }
        }
    }

    function _PaybackCalculate(AaveInterface aave, AaveDataRaw memory _data, address sourceDsa) internal returns (uint[] memory stableBorrow, uint[] memory variableBorrow, uint[] memory totalBorrow) {
        for (uint i = 0; i < _data.borrowTokens.length; i++) {
            require(isSupportedToken[_data.borrowTokens[i]], "token-not-enabled");
            address _token = _data.borrowTokens[i] == ethAddr ? wethAddr : _data.borrowTokens[i];
            _data.borrowTokens[i] = _token;

            (
                ,
                uint stableDebt,
                uint variableDebt,
                ,,,,,
            ) = aaveData.getUserReserveData(_token, sourceDsa);

            stableBorrow[i] = _data.stableBorrowAmts[i] == uint(-1) ? stableDebt : _data.stableBorrowAmts[i];
            variableBorrow[i] = _data.variableBorrowAmts[i] == uint(-1) ? variableDebt : _data.variableBorrowAmts[i];

            totalBorrow[i] = add(stableBorrow[i], variableBorrow[i]);
            if (totalBorrow[i] > 0) {
                IERC20(_token).safeApprove(address(aave), totalBorrow[i]);
            }
            aave.borrow(_token, totalBorrow[i], 2, 3288, address(this));
        }
    }

    function _getAtokens(address dsa, address[] memory supplyTokens, uint[] memory supplyAmts) internal returns (uint[] memory finalAmts) {
        for (uint i = 0; i < supplyTokens.length; i++) {
            require(isSupportedToken[supplyTokens[i]], "token-not-enabled");
            address _token = supplyTokens[i] == ethAddr ? wethAddr : supplyTokens[i];
            (address _aToken, ,) = aaveData.getReserveTokensAddresses(_token);
            ATokenInterface aTokenContract = ATokenInterface(_aToken);
            uint _finalAmt;
            if (supplyAmts[i] == uint(-1)) {
                _finalAmt = aTokenContract.balanceOf(dsa);
            } else {
                _finalAmt = supplyAmts[i];
            }

            aTokenContract.transferFrom(dsa, address(this), finalAmts[i]);

            _finalAmt = wmul(_finalAmt, fee);
            finalAmts[i] = _finalAmt;

        }
    }

    // function _getParams(uint config) internal returns (
    //     uint liqudationThreshold, uint decimals
    // ) {
    //     liqudationThreshold = (config & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION;
    //     decimals = (config & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION;
    // }

    function isPositionSafe() internal returns (bool isOk) {
        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());
        (,,,,,uint healthFactor) = aave.getUserAccountData(address(this));
        uint minLimit = wdiv(1e18, safeRatioGap);
        isOk = healthFactor > minLimit;
        require(isOk, "position-at-risk");
    }

    function getTokensPrices(address[] memory tokens) internal view returns(uint[] memory tokenPricesInEth) {
        tokenPricesInEth = AavePriceOracle(aaveProvider.getPriceOracle()).getAssetsPrices(tokens);
    }
    
    // Liquidation threshold
    function getTokenLt(address[] memory tokens) internal view returns (uint[] memory decimals, uint[] memory tokenLts) {
        for (uint i = 0; i < tokens.length; i++) {
            (decimals[i],,tokenLts[i],,,,,,,) = aaveData.getReserveConfigurationData(tokens[i]);
        }
    }

    function convertTo18(uint amount, uint decimal) internal view returns (uint) {
        return amount * (10 ** (18 - decimal)); // TODO: verify this
    }

    // TODO: need to verify this throughly
    /*
     * Checks the position to migrate should have a safe gap from liquidation 
    */
    // TODO: which checkRatio to use?
    function _checkRatio(AaveData memory data) public {
        uint[] memory supplyTokenPrices = getTokensPrices(data.supplyTokens);
        (uint[] memory supplyDecimals, uint[] memory supplyLts) = getTokenLt(data.supplyTokens);

        uint[] memory borrowTokenPrices = getTokensPrices(data.borrowTokens);
        (uint[] memory borrowDecimals,) = getTokenLt(data.borrowTokens);
        uint netSupply;
        uint netBorrow;
        uint liquidation;
        for (uint i = 0; i < data.supplyTokens.length; i++) {
            uint _amt = wmul(convertTo18(data.supplyAmts[i], supplyDecimals[i]), supplyTokenPrices[i]);
            netSupply += _amt;
            liquidation += (_amt * supplyLts[i]) / 10000; // convert the number 8000 to 0.8
        }
        for (uint i = 0; i < data.borrowTokens.length; i++) {
            uint _amt = wmul(convertTo18(data.borrowAmts[i], borrowDecimals[i]), borrowTokenPrices[i]);
            netBorrow += _amt;
        }
        uint _dif = wmul(netSupply, sub(1e18, safeRatioGap));
        require(netBorrow < sub(liquidation, _dif), "position-is-risky-to-migrate");
    }

    // function _checkRatio(AaveData memory data) public returns (bool isOk) {
    //     uint totalCollateral;
    //     uint totalDebt;
    //     uint avgLiquidationThresold;

    //     for(uint i = 0; i < data.supplyTokens.length; i++) {
    //         address _token = data.supplyTokens[i] == ethAddr ? wethAddr : data.supplyTokens[i];
    //         ReserveConfigurationMap memory config = aave.getConfiguration(_token);
    //         (uint _liq, uint _dec) = _getParams(config.data);
    //         uint assetPrice = aaveOracle.getAssetPrice(_token);
    //         uint collateral = div(mul(assetPrice, data.supplyAmts[i]), 10**_dec);
    //         totalCollateral += collateral;
    //         avgLiquidationThresold += mul(collateral, _liq);
    //     }

    //     for(uint i = 0; data.borrowTokens.length; i++) {
    //         address _token = data.supplyTokens[i] == ethAddr ? wethAddr : data.supplyTokens[i];
    //         ReserveConfigurationMap memory config = aave.getConfiguration(_token);
    //         (, uint _dec) = _getParams(config.data);
    //         uint assetPrice = aaveOracle.getAssetPrice(_token);
    //         uint debt = div(mul(assetPrice, data.borrowAmts[i]), 10**_dec);
    //         totalDebt += debt;
    //     }

    //     if (totalCollateral > 0) {
    //         avgLiquidationThresold = div(avgLiquidationThresold, totalCollateral);
    //     }

    //     uint healthFactor = wdiv(percentMul(totalCollateral, avgLiquidationThresold), totalDebt);
    //     uint minLimit = wdiv(1e18, safeRatioGap);
    //     isOk = healthFactor > minLimit;
    //     require(isOk, "position-at-risk");
    // }
}