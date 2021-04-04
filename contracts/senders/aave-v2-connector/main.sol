pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { TokenInterface, AccountInterface } from "../../common/interfaces.sol";
import { AaveInterface, ATokenInterface, AaveData } from "./interfaces.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";

contract AaveMigrateResolver is Helpers, Events {

    // function migrate(
    //     address targetDsa,
    //     address[] calldata supplyTokens,
    //     address[] calldata borrowTokens
    // ) external payable returns (string memory _eventName, bytes memory _eventParam) {
    //     require(supplyTokens.length > 0, "0-length-not-allowed");
    //     require(targetDsa != address(0), "invalid-address");

    //     for (uint i = 0; i < supplyTokens.length; i++) {
    //         address _token = supplyTokens[i] == ethAddr ? wethAddr : supplyTokens[i];
    //         (address _aToken, ,) = aaveData.getReserveTokensAddresses(_token);
    //         ATokenInterface _aTokenContract = ATokenInterface(_aToken);
    //         _aTokenContract.approve(address(migrator), _aTokenContract.balanceOf(address(this)));
    //     }

    //     migrator.migrate(msg.sender, targetDsa, supplyTokens, borrowTokens);

    //     _eventName = "LogAaveV2Migrate(address,address,address[],address[])";
    //     _eventParam = abi.encode(msg.sender, targetDsa, supplyTokens, borrowTokens);
    // }

    function migrate(
        AaveData calldata _data
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        require(_data.supplyTokens.length > 0, "0-length-not-allowed");
        require(_data.supplyTokens.length == _data.supplyAmts.length, "invalid-length");
        require(_data.targetDsa != address(0), "invalid-address");
        require(!_data.isFinal, "wrong-data");

        AaveData memory data;

        data.borrowTokens = _data.borrowTokens;
        data.isFinal = _data.isFinal;
        data.stableBorrowAmts = _data.stableBorrowAmts;
        data.supplyAmts = _data.supplyAmts;
        data.supplyTokens = _data.supplyTokens;
        data.targetDsa = _data.targetDsa;
        data.variableBorrowAmts = _data.variableBorrowAmts;

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

        migrator.migrate(msg.sender, data);

        _eventName = "LogAaveV2Migrate(address,address,address[],address[])";
        _eventParam = abi.encode(msg.sender, data.targetDsa, data.supplyTokens, data.borrowTokens);
    }
}

contract AaveV2Migrator is AaveMigrateResolver {
    string constant public name = "AaveV2PolygonMigrator-v1";
}