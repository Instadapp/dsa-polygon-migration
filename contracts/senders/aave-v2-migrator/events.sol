pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

contract Events {
    event LogDeposit(
        address owner,
        address[] tokens,
        uint256[] amts
    );

    event LogWithdraw(
        address owner,
        address[] tokens,
        uint256[] amts
    );

    event LogSettle(
        address[] tokens,
        uint256[] amts
    );

    event LogAaveV2Migrate(
        address indexed user,
        address indexed targetDsa,
        address[] supplyTokens,
        address[] borrowTokens,
        uint256[] supplyAmts,
        uint256[] variableBorrowAmts,
        uint256[] stableBorrowAmts
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

    event LogAddTokensSupport(address[] _tokens);

    event variablesUpdate(uint _safeRatioGap, uint _fee, bool _depositEnable);

    event settle(address[] tokens, uint[] amts);

}