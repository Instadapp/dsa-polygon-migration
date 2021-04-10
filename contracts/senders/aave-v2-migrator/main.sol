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

            deposits[msg.sender][_token] = sub(maxAmt, _amt);

            if (_token == ethAddr) {
                TokenInterface _tokenContract = TokenInterface(wethAddr);
                uint _ethBal = address(this).balance;
                uint _tknBal = _tokenContract.balanceOf(address(this));
                if ((_ethBal + _tknBal) < _amt) {
                    aave.withdraw(wethAddr, sub(_amt, (_tknBal + _ethBal)), address(this));
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
        }

        isPositionSafe();

        emit LogWithdraw(msg.sender, tokens, _amts);
    }

    /**
     * @param _tokens - array of tokens to transfer to L2 receiver's contract
     * @param _amts - array of token amounts to transfer to L2 receiver's contract
     */
    function settle(address[] calldata _tokens, uint[] calldata _amts) external {
        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());
        for (uint i = 0; i < supportedTokens.length; i++) {
            address _token = supportedTokens[i];
            if (_token == ethAddr) {
                _token = wethAddr;
                if (address(this).balance > 0) {
                    TokenInterface(wethAddr).deposit{value: address(this).balance}();
                }
            }
            IERC20 _tokenContract = IERC20(_token);
            uint _tokenBal = _tokenContract.balanceOf(address(this));
            if (_tokenBal > 0) {
                _tokenContract.approve(address(this), _tokenBal);
                aave.deposit(_token, _tokenBal, address(this), 3288);
            }
            (
                uint supplyBal,,
                uint borrowBal,
                ,,,,,
            ) = aaveData.getUserReserveData(_token, address(this));
            if (supplyBal != 0 && borrowBal != 0) {
                if (supplyBal > borrowBal) {
                    aave.withdraw(_token, borrowBal, address(this)); // TODO: fail because of not enough withdrawing capacity?
                    IERC20(_token).approve(address(aave), borrowBal);
                    aave.repay(_token, borrowBal, 2, address(this));
                } else {
                    aave.withdraw(_token, supplyBal, address(this)); // TODO: fail because of not enough withdrawing capacity?
                    IERC20(_token).approve(address(aave), supplyBal);
                    aave.repay(_token, supplyBal, 2, address(this));
                }
            }
        }
        for (uint i = 0; i < _tokens.length; i++) {
            aave.withdraw(_tokens[i], _amts[i], address(this));
            // TODO: transfer to polygon's receiver address "polygonReceiver"
            isPositionSafe();
        }
    }
    // TODO: emit event
}

contract MigrateResolver is LiquidityResolver {
    using SafeERC20 for IERC20;

    function _migrate(
        AaveInterface aave,
        AaveDataRaw memory _data,
        address sourceDsa,
        uint ethAmt
    ) internal {
        require(_data.supplyTokens.length > 0, "0-length-not-allowed");
        require(_data.targetDsa != address(0), "invalid-address");
        require(_data.supplyTokens.length == _data.supplyAmts.length, "invalid-length");
        require(
            _data.borrowTokens.length == _data.variableBorrowAmts.length &&
            _data.borrowTokens.length == _data.stableBorrowAmts.length,
            "invalid-length"
        );

        if (ethAmt > 0) {
            aave.deposit(wethAddr, ethAmt, address(this), 3288);
        }

        (uint[] memory stableBorrows, uint[] memory variableBorrows, uint[] memory totalBorrows) = _PaybackCalculate(aave, _data, sourceDsa);

        _PaybackStable(_data.borrowTokens.length, aave, _data.borrowTokens, stableBorrows, sourceDsa);
        _PaybackVariable(_data.borrowTokens.length, aave, _data.borrowTokens, variableBorrows, sourceDsa);

        (uint[] memory totalSupplies) = _getAtokens(sourceDsa, aave, _data.supplyTokens, _data.supplyAmts);

        // Aave on Polygon doesn't have stable borrowing so we'll borrow all the debt in variable
        AaveData memory data;

        data.borrowTokens = _data.borrowTokens;
        data.borrowAmts = _data.stableBorrowAmts;
        data.supplyAmts = totalSupplies;
        data.supplyTokens = _data.supplyTokens;
        data.targetDsa = _data.targetDsa;
        data.borrowAmts = totalBorrows;

        // Checks the amount that user is trying to migrate is 20% below the Liquidation
        _checkRatio(data);

        if (ethAmt > 0) {
            aave.withdraw(wethAddr, ethAmt, address(this));
        }

        isPositionSafe();

        stateSender.syncState(polygonReceiver, abi.encode(data));

        emit LogAaveV2Migrate(
            sourceDsa,
            data.targetDsa,
            data.supplyTokens,
            data.borrowTokens,
            totalSupplies,
            variableBorrows,
            stableBorrows
        );
    }

    function migrate(AaveDataRaw calldata _data) external {
        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());
        _migrate(aave, _data, msg.sender, 0);
    }

    function migrateFlashCallback(AaveDataRaw calldata _data, address dsa, uint ethAmt) external {
        require(msg.sender == address(flashloanContract), "not-flashloan-contract"); // TODO: flash loan contract
        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        TokenInterface wethContract = TokenInterface(wethAddr);
        wethContract.approve(address(aave), ethAmt);
        _migrate(aave, _data, dsa, ethAmt);
        wethContract.transfer(address(flashloanContract), ethAmt);
    }

    function migrateWithFlash(AaveDataRaw calldata _data, uint ethAmt) external {
        bytes memory data = abi.encode(_data, msg.sender, ethAmt);

        flashloanContract.initiateFlashLoan(data, ethAmt);
    }

}