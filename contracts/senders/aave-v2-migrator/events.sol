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

    event LogAddTokensSupport(address[] _tokens);

    event variablesUpdate(uint _safeRatioGap, uint _fee, bool _depositEnable);

    event settle(address[] tokens, uint[] amts);

}