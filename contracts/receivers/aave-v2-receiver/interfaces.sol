pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface AccountInterface {
    function enable(address) external;
    function disable(address) external;
    function isAuth(address) external view returns (bool);
    function cast(
        string[] calldata _targets,
        bytes[] calldata _datas,
        address _origin
    ) external payable returns (bytes32);
    function migrateAave(address) external payable returns (bytes32);
}