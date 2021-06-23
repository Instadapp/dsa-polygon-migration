// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/proxy/ProxyAdmin.sol";

/**
 * @dev This is an auxiliary contract meant to be assigned as the admin of a {TransparentUpgradeableProxy}. For an
 * explanation of why you would want to use this see the documentation for {TransparentUpgradeableProxy}.
 */
contract InstaMasterProxy is ProxyAdmin {
    constructor(address masterAddress) {
        require(masterAddress != address(0), "not-vaild-address");
        transferOwnership(masterAddress);
    }
}