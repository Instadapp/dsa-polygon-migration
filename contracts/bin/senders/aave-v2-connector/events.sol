pragma solidity ^0.7.0;

contract Events {
    event LogAaveV2Migrate(
        address indexed user,
        address indexed targetDsa,
        address[] supplyTokens,
        address[] borrowTokens
    );
}