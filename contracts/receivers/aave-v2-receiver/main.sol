pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TokenInterface } from "../../common/interfaces.sol";
import { AccountInterface, AaveData, AaveInterface, IndexInterface, CastData, DSAInterface } from "./interfaces.sol";
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
        for (uint i = 0; i < supportedTokens.length; i++) {
            delete isSupportedToken[supportedTokens[i]];
        }
        delete supportedTokens;
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

    function settle() external {
        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());
        for (uint i = 0; i < supportedTokens.length; i++) {
            address _token = supportedTokens[i];
            if (_token == wmaticAddr) {
                if (address(this).balance > 0) {
                    TokenInterface(wmaticAddr).deposit{value: address(this).balance}();
                }
            }

            IERC20 _tokenContract = IERC20(_token);
            uint _tokenBal = _tokenContract.balanceOf(address(this));
            if (_tokenBal > 0) {
                _tokenContract.approve(address(aave), _tokenBal);
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
        emit LogSettle();
    }

}

contract AaveV2Migrator is MigrateResolver {
    using SafeERC20 for IERC20;

    function _migratePosition(AaveData memory _data) internal {
        AaveData memory data = remapTokens(_data); // converting L1 token addresses to L2 addresses

        address dsa = data.targetDsa;
        uint[] memory supplyAmts = data.supplyAmts;
        uint[] memory borrowAmts = data.borrowAmts;
        address[] memory supplyTokens = data.supplyTokens;
        address[] memory borrowTokens = data.borrowTokens;

        require(instaList.accountID(dsa) != 0, "not-a-dsa");
        require(AccountInterface(dsa).version() == 2, "not-v2-dsa");

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        transferAtokens(aave, dsa, supplyTokens, supplyAmts);

        // Have to borrow from user's account & transfer
        borrowAndTransferSpells(dsa, supplyTokens, borrowTokens, borrowAmts);

        isPositionSafe();

        emit LogAaveV2Migrate(dsa, supplyTokens, borrowTokens, supplyAmts, borrowAmts);
    }

    function onStateReceive(uint256 stateId, bytes calldata receivedData) external {
        // Add some more require statements. Any kind of hashing for better privacy?
        require(msg.sender == maticReceiver, "not-receiver-address");
        require(stateId > lastStateId, "wrong-data");
        lastStateId = stateId;

        // TODO: what's the best way to store user's data to create position later.
        // Can't do it via any address as user can migrate 2 times 
        positions[stateId] = receivedData;

        emit LogStateSync(stateId, receivedData);
    }
}

contract InstaFlash is AaveV2Migrator {

    using SafeERC20 for IERC20;

    /**
     * FOR SECURITY PURPOSE
     * only Smart DEFI Account can access the liquidity pool contract
     */
    modifier isDSA {
        uint64 id = instaList.accountID(msg.sender);
        require(id != 0, "not-dsa-id");
        _;
    }

    function initiateFlashLoan(
        address[] calldata _tokens,	
        uint256[] calldata _amounts,	
        uint /*_route */, // no use of route but just to follow current flashloan pattern
        bytes calldata data
    ) external isDSA {	
        uint _length = _tokens.length;
        require(_length == _amounts.length, "not-equal-length");
        uint[] memory iniBal = new uint[](_length);
        IERC20[] memory _tokenContracts = new IERC20[](_length);
        for (uint i = 0; i < _length; i++) {
            _tokenContracts[i] = IERC20(_tokens[i]);
            iniBal[i] = _tokenContracts[i].balanceOf(address(this));
            _tokenContracts[i].safeTransfer(msg.sender, _amounts[i]);
        }
        CastData memory cd;
        (cd.dsa, cd.route, cd.tokens, cd.amounts, cd.dsaTargets, cd.dsaData) = abi.decode(
            data,
            (address, uint256, address[], uint256[], address[], bytes[])
        );
        DSAInterface(msg.sender).cast(cd.dsaTargets, cd.dsaData, 0xB7fA44c2E964B6EB24893f7082Ecc08c8d0c0F87);
        for (uint i = 0; i < _length; i++) {
            uint _finBal = _tokenContracts[i].balanceOf(address(this));
            require(_finBal >= iniBal[i], "flashloan-not-returned");
        }
        // TODO: emit event
    }

}

contract InstaAaveV2MigratorReceiverImplementation is AaveV2Migrator {
    function migrate(uint _id) external {
        bytes memory _data = positions[_id];

        require(_data.length != 0, "already-migrated");
        
        AaveData memory data = abi.decode(_data, (AaveData));

        _migratePosition(data);

        delete positions[_id];

        emit LogMigrate(_id);
    }

    receive() external payable {}
}
