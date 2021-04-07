pragma solidity ^0.7.0;

import { DSMath } from "../../common/math.sol";
import { Stores } from "../../common/stores-mainnet.sol";

import { 
    AaveLendingPoolProviderInterface,
    AaveDataProviderInterface,
    AaveInterface,
    StateSenderInterface
} from "./interfaces.sol";

abstract contract Helpers is DSMath, Stores {
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

    function _Withdraw(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                aave.withdraw(tokens[i], amts[i], address(this));
            }
        }
    }
}