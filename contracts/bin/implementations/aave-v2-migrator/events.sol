pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

contract Events {
    event LogMigrateAaveV2(
        address indexed owner,
        address[] supplyTokens,
        address[] borrowTokens,
        uint[] supplyAmts,
        uint[] variableBorrowAmts,
        uint[] stableBorrowAmts
    );
}