pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { TokenInterface, AccountInterface } from "../../common/interfaces.sol";
import { AaveInterface, ATokenInterface } from "./interfaces.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";

contract AaveMigrateResolver is Helpers, Events {

    function migrate(
        address targetDsa,
        address[] calldata supplyTokens,
        address[] calldata borrowTokens
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        require(supplyTokens.length > 0, "0-length-not-allowed");
        require(targetDsa != address(0), "invalid-address");

        for (uint i = 0; i < supplyTokens.length; i++) {
            address _token = supplyTokens[i] == ethAddr ? wethAddr : supplyTokens[i];
            (address _aToken, ,) = aaveData.getReserveTokensAddresses(_token);
            ATokenInterface _aTokenContract = ATokenInterface(_aToken);
            _aTokenContract.approve(address(migrator), _aTokenContract.balanceOf(address(this)));
        }

        migrator.migrate(msg.sender, targetDsa, supplyTokens, borrowTokens);

        _eventName = "LogAaveV2Migrate(address,address,address[],address[])";
        _eventParam = abi.encode(msg.sender, targetDsa, supplyTokens, borrowTokens);
    }
}

contract AaveV2Migrator is AaveMigrateResolver {
    string constant public name = "AaveV2PolygonMigrator-v1";
}