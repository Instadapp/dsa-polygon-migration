pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

contract Events {
    event LogDeposit(
        address owner,
        address[] tokens,
        uint[] amts
    );

    event LogWithdraw(
        address owner,
        address[] tokens,
        uint[] amts
    );

    event LogAaveV2Migrate(
        address indexed user,
        address indexed targetDsa,
        address[] supplyTokens,
        address[] borrowTokens,
        uint[] supplyAmts,
        uint[] variableBorrowAmts,
        uint[] stableBorrowAmts
    );

    event LogUpdateVariables(
        uint256 oldFee,
        uint256 newFee,
        uint256 oldSafeRatioGap,
        uint256 newSafeRatioGap
    );

    event LogAddSupportedTokens(
        uint256[] tokens
    );
}