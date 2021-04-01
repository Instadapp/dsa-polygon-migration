pragma solidity ^0.7.0;

contract Events {
    event LogAaveV2Migrate(
        address indexed user,
        address[] supplyTokens,
        address[] borrowTokens,
        uint[] supplyAmts,
        uint[] stableBorrowAmts,
        uint[] variableBorrowAmts
    );
}