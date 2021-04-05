pragma solidity >=0.7.0;

import { DSMath } from "../../common/math.sol";
import { Stores } from "../../common/stores.sol";

import { 
    AaveLendingPoolProviderInterface,
    AaveDataProviderInterface,
    AaveInterface,
    StateSenderInterface
} from "./interfaces.sol";

abstract contract Helpers is DSMath, Stores {

    struct AaveDataRaw {
        address targetDsa;
        uint[] supplyAmts;
        uint[] variableBorrowAmts;
        uint[] stableBorrowAmts;
        address[] supplyTokens;
        address[] borrowTokens;
    }

    struct AaveData {
        address targetDsa;
        uint[] supplyAmts;
        uint[] borrowAmts;
        address[] supplyTokens;
        address[] borrowTokens;
    }

    /**
     * @dev Aave referal code
     */
    uint16 constant internal referralCode = 3228;

    address constant internal polygonReceiver = address(2); // Replace this

    /**
     * @dev Aave Provider
     */
    AaveLendingPoolProviderInterface constant internal aaveProvider = AaveLendingPoolProviderInterface(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);

    /**
     * @dev Aave Data Provider
     */
    AaveDataProviderInterface constant internal aaveData = AaveDataProviderInterface(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    /**
     * @dev Polygon State Sync Contract
     */
    StateSenderInterface constant internal stateSender = StateSenderInterface(0x28e4F3a7f651294B9564800b2D01f35189A5bFbE);

    function _borrow(address _token, uint _amt) internal {
    }

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

    function _PaybackCalculate(AaveInterface aave, AaveDataRaw memory _data, address sourceDsa) internal returns (uint[] stableBorrow, uint[] variableBorrow, uint[] totalBorrow) {
        for (uint i = 0; i < data.borrowTokens.length; i++) {
            address _token = data.borrowTokens[i] == ethAddr ? wethAddr : data.borrowTokens[i];
            data.borrowTokens[i] = _token;

            (
                ,
                uint stableDebt,
                uint variableDebt,
                ,,,,,
            ) = aaveData.getUserReserveData(_token, sourceDsa);

            stableBorrow[i] = data.stableBorrowAmts[i] == uint(-1) ? stableDebt : data.stableBorrowAmts[i];
            variableBorrow[i] = data.variableBorrowAmts[i] == uint(-1) ? variableDebt : data.variableBorrowAmts[i];

            totalBorrow[i] = add(stableBorrow[i], variableBorrow[i]);
            if (totalBorrowAmt > 0) {
                IERC20(_token).safeApprove(address(aave), totalBorrow[i]); // TODO: Approval is to Aave address of atokens address?
            }
            aave.borrow(_token, totalBorrow[i], 2, 3088, address(this)); // TODO: Borrowing debt to payback
        }
    }

    function _getAtokens(AaveInterface aave, address[] memory supplyTokens, uint[] memory supplyAmts, uint fee) internal returns (uint[] finalAmts) {
        for (uint i = 0; i < supplyTokens.length; i++) {
            (address _aToken, ,) = aaveData.getReserveTokensAddresses(supplyTokens[i]);
            ATokenInterface aTokenContract = ATokenInterface(_aToken);

            // TODO: deduct the fee from finalAmt
            if (supplyAmts[i] == uint(-1)) {
                // TODO: get maximum balance and set the return variable
            } else {
                finalAmts[i] = supplyAmts[i];
            }

            aTokenContract.transferFrom(sourceDsa, address(this), finalAmts[i]);
        }
    }

    function _checkRatio(AaveData data, uint _safeRatioGap) returns (bool isOk) {
        // TODO: Check the debt/collateral ratio should be less than "_safeRatioGap" from Liquidation of that particular user assets
    }

}