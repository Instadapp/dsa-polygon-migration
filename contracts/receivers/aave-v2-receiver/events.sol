pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

contract Events {
    event LogUpdateSafeRatioGap(
        uint256 oldSafeRatioGap,
        uint256 newSafeRatioGap
    );

    event LogAddSupportedTokens(
        address[] tokens
    );

    event LogSettle();

    event LogAaveV2Migrate(
        address indexed user,
        address[] supplyTokens,
        address[] borrowTokens,
        uint256[] supplyAmts,
        uint256[] borrowAmts
    );

    event LogStateSync(
        uint256 indexed stateId,
        bytes data
    );

    event LogMigrate(uint _id);
}