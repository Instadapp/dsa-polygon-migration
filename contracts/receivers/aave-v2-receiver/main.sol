pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TokenInterface } from "../../common/interfaces.sol";
import { AccountInterface, AaveData, AaveInterface, IndexInterface } from "./interfaces.sol";
import { Events } from "./events.sol";
import { Helpers } from "./helpers.sol";

contract MigrateResolver is Helpers, Events {
    using SafeERC20 for IERC20;

    function updateSafeRatioGap(uint _safeRatioGap) public {
        require(msg.sender == instaIndex.master(), "not-master");
        emit LogUpdateSafeRatioGap(safeRatioGap, _safeRatioGap);
        safeRatioGap = _safeRatioGap;
    }

    function addTokenSupport(address[] memory _tokens) public {
        require(msg.sender == instaIndex.master(), "not-master");
        for (uint i = 0; i < _tokens.length; i++) {
            require(!isSupportedToken[_tokens[i]], "already-added");
            isSupportedToken[_tokens[i]] = true;
            supportedTokens.push(_tokens[i]);
        }
        emit LogAddSupportedTokens(_tokens);
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

    // TODO: change deposit to single token at once as msg.value == amt[i] can lead to double ETH deposit
    function deposit(address[] calldata tokens, uint[] calldata amts) external payable {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            require(isSupportedToken[tokens[i]], "token-not-enabled");
            uint _amt;
            bool isMatic = tokens[i] == maticAddr;
            address _token = isMatic ? wmaticAddr : tokens[i];

            IERC20 tokenContract = IERC20(_token);

            if (isMatic) {
                require(msg.value == amts[i]);
                TokenInterface(_token).deposit{value: msg.value}();
                _amt = msg.value;
            } else {
                _amt = amts[i] == uint(-1) ? tokenContract.balanceOf(msg.sender) : amts[i];
                tokenContract.safeTransferFrom(msg.sender, address(this), _amt);
            }

            tokenContract.safeApprove(address(aave),_amt);
            aave.deposit(_token, _amt, address(this), 3288);

            _amts[i] = _amt;

            deposits[msg.sender][_token] += _amt;
        }

        emit LogDeposit(msg.sender, tokens, _amts);
    }

    // TODO: change withdraw to single token at once as msg.value == amt[i] can lead to double ETH deposit
    function withdraw(address[] calldata tokens, uint[] calldata amts) external {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            require(isSupportedToken[tokens[i]], "token-not-enabled");
            uint _amt = amts[i];
            bool isMatic = tokens[i] == maticAddr;
            address _token = isMatic ? wmaticAddr : tokens[i];
            uint maxAmt = deposits[msg.sender][_token];

            if (_amt > maxAmt) {
                _amt = maxAmt;
            }

            deposits[msg.sender][_token] = sub(maxAmt, _amt);

            if (isMatic) {
                TokenInterface _tokenContract = TokenInterface(wmaticAddr);
                uint _maticBal = address(this).balance;
                uint _tknBal = _tokenContract.balanceOf(address(this));
                if ((_maticBal + _tknBal) < _amt) {
                    aave.withdraw(wmaticAddr, sub(_amt, (_tknBal + _maticBal)), address(this));
                }
                _tokenContract.withdraw((sub(_amt, _maticBal)));
                msg.sender.call{value: _amt}("");
                _amts[i] = _amt;
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

    function settle() external {
        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());
        for (uint i = 0; i < supportedTokens.length; i++) {
            address _token = supportedTokens[i];
            if (_token == maticAddr) {
                _token = wmaticAddr;
                if (address(this).balance > 0) {
                    TokenInterface(wmaticAddr).deposit{value: address(this).balance}();
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
                    aave.withdraw(_token, (borrowBal + flashAmts[_token]), address(this)); // TODO: fail because of not enough withdrawing capacity?
                    IERC20(_token).approve(address(aave), borrowBal);
                    aave.repay(_token, borrowBal, 2, address(this));
                } else {
                    aave.withdraw(_token, (supplyBal + flashAmts[_token]), address(this)); // TODO: fail because of not enough withdrawing capacity?
                    IERC20(_token).approve(address(aave), supplyBal);
                    aave.repay(_token, supplyBal, 2, address(this));
                }
            }
        }
        emit LogSettle();
    }

}

contract AaveV2Migrator is MigrateResolver {
    using SafeERC20 for IERC20;

    uint private lastStateId;

    function _migratePosition(AaveData memory _data) internal {
        AaveData memory data = remapTokens(_data); // converting L1 token addresses to L2 addresses

        address dsa = _data.targetDsa;
        uint[] memory supplyAmts = _data.supplyAmts;
        uint[] memory borrowAmts = _data.borrowAmts;
        address[] memory supplyTokens = _data.supplyTokens;
        address[] memory borrowTokens = _data.borrowTokens;

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        transferAtokens(aave, dsa, supplyTokens, supplyAmts);

        // Have to borrow from user's account & transfer
        borrowAndTransferSpells(aave, dsa, borrowTokens, borrowAmts);

        isPositionSafe();

        emit LogAaveV2Migrate(dsa, supplyTokens, borrowTokens, supplyAmts, supplyAmts);
    }

    function onStateReceive(uint256 stateId, bytes calldata receivedData) external {
        require(stateId > lastStateId, "wrong-data");
        lastStateId = stateId;

        // TODO: what's the best way to store user's data to create position later.
        // Can't do it via any address as user can migrate 2 times 
        positions[stateId] = receivedData;

        emit LogStateSync(stateId, receivedData);
    }

    function migrate(uint _id) external {
        bytes memory _data = positions[_id];

        require(_data.length != 0, "already-migrated");
        
        AaveData memory data = abi.decode(_data, (AaveData));

        _migratePosition(data);

        delete positions[_id];
    }
}
