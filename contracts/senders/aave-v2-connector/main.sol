pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { TokenInterface, AccountInterface } from "../../common/interfaces.sol";
import { AaveInterface, ATokenInterface, AaveDataRaw } from "./interfaces.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";

contract AaveMigrateResolver is Helpers, Events {

    function migrate(
        address targetDsa,
        address[] memory supplyTokens,
        address[] memory borrowTokens,
        uint[] memory variableBorrowAmts,
        uint[] memory stableBorrowAmts,
        uint[] memory supplyAmts,
        uint ethAmt // if ethAmt is > 0 then use migrateWithflash
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        require(supplyTokens.length > 0, "0-length-not-allowed");
        require(supplyTokens.length == supplyAmts.length, "invalid-length");
        require(borrowTokens.length == variableBorrowAmts.length && borrowTokens.length  == stableBorrowAmts.length, "invalid-length");
        require(targetDsa != address(0), "invalid-address");

        AaveDataRaw memory data;

        data.targetDsa = targetDsa;
        data.supplyTokens = supplyTokens;
        data.borrowTokens = borrowTokens;
        data.variableBorrowAmts = variableBorrowAmts;
        data.stableBorrowAmts = stableBorrowAmts;
        data.supplyAmts = supplyAmts;

        for (uint i = 0; i < data.supplyTokens.length; i++) {
            address _token = data.supplyTokens[i] == ethAddr ? wethAddr : data.supplyTokens[i];
            data.supplyTokens[i] = _token;
            (address _aToken, ,) = aaveData.getReserveTokensAddresses(_token);
            ATokenInterface _aTokenContract = ATokenInterface(_aToken);

            if (data.supplyAmts[i] == uint(-1)) {
                data.supplyAmts[i] = _aTokenContract.balanceOf(address(this));
            }

            _aTokenContract.approve(address(migrator), data.supplyAmts[i]);
        }

        if (ethAmt > 0) {
            migrator.migrateWithFlash(data, ethAmt);
        } else {
            migrator.migrate(data);
        }

        _eventName = "LogAaveV2Migrate(address,address,address[],address[])";
        _eventParam = abi.encode(msg.sender, data.targetDsa, data.supplyTokens, data.borrowTokens);
    }

}

contract AaveV2Migrator is AaveMigrateResolver {
    string constant public name = "AaveV2PolygonMigrator-v1";
}