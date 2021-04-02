pragma solidity ^0.7.0;

import { DSMath } from "../../common/math.sol";
import { Stores } from "../../common/stores.sol";
import { AaveLendingPoolProviderInterface, AaveDataProviderInterface, AaveMigratorInterface } from "./interfaces.sol";

abstract contract Helpers is DSMath, Stores {

    AaveMigratorInterface constant internal migrator = AaveMigratorInterface(address(2)); // Replace this (Migrator contract)

    /**
     * @dev Aave Data Provider
     */
    AaveDataProviderInterface constant internal aaveData = AaveDataProviderInterface(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);
}
