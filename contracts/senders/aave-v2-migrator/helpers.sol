pragma solidity >=0.7.0;
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
    StateSenderInterface
} from "./interfaces.sol";

abstract contract Helpers is DSMath, Stores, Variables {

    function _paybackBehalfOne(AaveInterface aave, address token, uint amt, uint rateMode, address user) private {
        aave.repay(token, amt, rateMode, user);
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
                IERC20(_token).approve(address(aave), totalBorrow[i]); // TODO: Approval is to Aave address of atokens address?
            }
            aave.borrow(_token, totalBorrow[i], 2, 3088, address(this)); // TODO: Borrowing debt to payback
        }
    }

    function _getAtokens(address dsa, AaveInterface aave, address[] memory supplyTokens, uint[] memory supplyAmts) internal returns (uint[] memory finalAmts) {
        for (uint i = 0; i < supplyTokens.length; i++) {
            require(isSupportedToken[supplyTokens[i]], "token-not-enabled");
            (address _aToken, ,) = aaveData.getReserveTokensAddresses(supplyTokens[i]);
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

    function isPositionSafe() internal returns (bool isOk) {
        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());
        (,,,,,uint healthFactor) = aave.getUserAccountData(address(this));
        // TODO: Check throughly minLimit = 100%/80% = 125% (20% gap initially)
        uint minLimit = wdiv(1e18, safeRatioGap);
        isOk = healthFactor > minLimit;
        require(isOk, "position-at-risk");
    }

    function _checkRatio(AaveData memory data) public returns (bool isOk) {
        // TODO: @mubaris Check the debt/collateral ratio should be less than "safeRatioGap" from Liquidation of that particular user assets
    }

}