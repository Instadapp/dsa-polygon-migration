pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TokenInterface } from "../../common/interfaces.sol";
import { Helpers } from "./helpers.sol";
import { AaveInterface, ATokenInterface, IndexInterface } from "./interfaces.sol";
import { Events } from "./events.sol";

contract LiquidityResolver is Helpers, Events {
    using SafeERC20 for IERC20;

    event variablesUpdate(uint _safeRatioGap, uint _fee);

    function updateVariables(uint _safeRatioGap, uint _fee) public {
        require(msg.sender == instaIndex.master(), "not-master");
        safeRatioGap = _safeRatioGap;
        fee = _fee;
        emit variablesUpdate(safeRatioGap, fee);
    }

    function addTokenSupport(address[] memory _tokens) public {
        require(msg.sender == instaIndex.master(), "not-master");
        for (uint i = 0; i < _tokens.length; i++) {
            isSupportedToken[_tokens[i]] = true;
        }
        supportedTokens = _tokens;
        // TODO: add event
    }

    function spell(address _target, bytes memory _data) external {
        require(msg.sender == instaIndex.master(), "not-master");
        require(_target != address(0), "target-invalid");
        assembly {
            let succeeded := delegatecall(gas(), _target, add(_data, 0x20), mload(_data), 0, 0)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    let size := returndatasize()
                    returndatacopy(0x00, 0x00, size)
                    revert(0x00, size)
                }
        }
    }

    function deposit(address[] calldata tokens, uint[] calldata amts) external payable {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            require(isSupportedToken[tokens[i]], "token-not-enabled");
            uint _amt;
            address _token = tokens[i];
            if (_token == ethAddr) {
                require(msg.value == amts[i]);
                _amt = msg.value;
                TokenInterface(wethAddr).deposit{value: msg.value}();
                aave.deposit(wethAddr, _amt, address(this), 3288);
            } else {
                IERC20 tokenContract = IERC20(_token);
                _amt = amts[i] == uint(-1) ? tokenContract.balanceOf(msg.sender) : amts[i];
                tokenContract.safeTransferFrom(msg.sender, address(this), _amt);
                aave.deposit(_token, _amt, address(this), 3288);
            }

            _amts[i] = _amt;

            deposits[msg.sender][_token] += _amt;
        }

        emit LogDeposit(msg.sender, tokens, _amts);
    }

    function withdraw(address[] calldata tokens, uint[] calldata amts) external {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            require(isSupportedToken[tokens[i]], "token-not-enabled");
            uint _amt = amts[i];
            address _token = tokens[i];
            uint maxAmt = deposits[msg.sender][_token];

            if (_amt > maxAmt) {
                _amt = maxAmt;
            }

            // TODO: @everyone check this throughly. Saving 1000 WEI for flashloan WETH. Also, should we make a different contract to handle 2 WEI dydx gas, I think this would be better.
            if (_token == ethAddr) {
                TokenInterface _tokenContract = TokenInterface(wethAddr);
                uint _ethBal = address(this).balance;
                uint _tknBal = _tokenContract.balanceOf(address(this));
                if ((_ethBal + _tknBal + 1000) < _amt) {
                    aave.withdraw(wethAddr, sub((_amt + 1000), (_tknBal + _ethBal)), address(this));
                }
                _tokenContract.withdraw((sub(_amt, _ethBal)));
                msg.sender.call{value: _amt}("");
            } else {
                IERC20 _tokenContract = IERC20(_token);
                uint _tknBal = _tokenContract.balanceOf(address(this));
                if (_tknBal < _amt) {
                    aave.withdraw(_token, sub(_amt, _tknBal), address(this));
                }
                _tokenContract.safeTransfer(msg.sender, _amt);
            }

            _amts[i] = _amt;

            deposits[msg.sender][_token] = sub(maxAmt, _amt);
        }

        isPositionSafe();

        emit LogWithdraw(msg.sender, tokens, _amts);
    }

    // TODO: @mubaris Things to factor
    // use supportedTokens array to loop through
    // If there is same token supply and borrow, then close the smaller one
    // If there is ideal token then payback or deposit according to the position
    // Object is the decrease the ratio and pay as less interest
    // If ratio is safe then transfer excess collateral to L2 migration contract
    // Always, keep 1000 wei WETH ideal for flashloan
    function settle() external {

    }

}

contract MigrateResolver is LiquidityResolver {
    using SafeERC20 for IERC20;

    function _migrate(AaveDataRaw memory _data, address sourceDsa) internal {
        require(_data.supplyTokens.length > 0, "0-length-not-allowed");
        require(_data.targetDsa != address(0), "invalid-address");
        require(_data.supplyTokens.length == _data.supplyAmts.length, "invalid-length");
        require(
            _data.borrowTokens.length == _data.variableBorrowAmts.length &&
            _data.borrowTokens.length == _data.stableBorrowAmts.length,
            "invalid-length"
        );

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        (,,,,,uint healthFactor) = aave.getUserAccountData(sourceDsa);
        require(healthFactor > 1e18, "position-not-safe");

        (uint[] stableBorrows, uint[] variableBorrows, uint[] totalBorrows) = _PaybackCalculate(aave, _data, sourceDsa);

        _PaybackStable(_data.borrowTokens.length, aave, _data.borrowTokens, stableBorrows, sourceDsa);
        _PaybackVariable(_data.borrowTokens.length, aave, _data.borrowTokens, variableBorrows, sourceDsa);

        (uint[] totalSupplies) = _getAtokens(sourceDsa, aave, _data.supplyTokens, _data.supplyAmts, fee);

        // Aave on Polygon doesn't have stable borrowing so we'll borrow all the debt in variable
        AaveData memory data;

        data.borrowTokens = _data.borrowTokens;
        data.stableBorrowAmts = _data.stableBorrowAmts;
        data.supplyAmts = totalSupplies;
        data.supplyTokens = _data.supplyTokens;
        data.targetDsa = _data.targetDsa;
        data.borrowAmts = totalBorrows;

        // Checks the amount that user is trying to migrate is 20% below the Liquidation
        bool isOk = _checkRatio(data);
        require(isOk, "position-risky-to-migrate");

        isPositionSafe();

        bytes memory positionData = data; // TODO: @everyone Can we do anything else to make the data more secure? (It's secure already)
        stateSender.syncState(polygonReceiver, positionData);

        emit LogAaveV2Migrate(
            sourceDsa,
            data.targetDsa,
            data.supplyTokens,
            data.borrowTokens,
            data.supplyAmts,
            data.variableBorrowAmts,
            data.stableBorrowAmts
        );
    }

    function migrate(AaveDataRaw calldata _data) external {
        _migrate(_data, msg.sender);
    }

    function migrateWithFlash(AaveDataRaw calldata _data, uint ethAmt) external {
        bytes data = abi.encode(_data, msg.sender, ethAmt);
        
        // TODO: @everyone integrate dydx flashloan and borrow "ethAmt" and transfer ETH to this address
        // Should we create a new contract for flashloan or interact directly from this contract? Mainly to resolve 2 WEI bug of dydx flashloan

    }

    // TODO: @everyone
    function callFunction(
        address sender,
        Account.Info memory account,
        bytes memory data
    ) public override {
        require(sender == address(this), "wrong-sender");
        // require(msg.sender == dydxFlash, "wrong-sender"); // TODO: msg.sender should be flashloan contract
        (address l2DSA, AaveDataRaw memory _data, address sourceDsa, uint ethAmt) = abi.decode(
            data,
            (address, AaveDataRaw, address, uint)
        );
        // TODO: deposit WETH "ethAmt" in Aave
        _migrate(l2DSA, _data, sourceDsa);
        // TODO: withdraw WETH "ethAmt" from Aave
        // TODO: approve WETH "ethAmt + 2" to dydx
    }

}