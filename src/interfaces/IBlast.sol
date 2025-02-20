// SPDX-License-Identifier: BSL 1.1 - Copyright 2024 MetaLayer Labs Ltd.
pragma solidity 0.8.24;

enum YieldMode {
    AUTOMATIC,
    VOID,
    CLAIMABLE
}

enum GasMode {
    VOID,
    CLAIMABLE
}

interface IGas {
    function readGasParams(address contractAddress) external view returns (uint256, uint256, uint256, GasMode);
    function setGasMode(address contractAddress, GasMode mode) external;
    function claimGasAtMinClaimRate(address contractAddress, address recipient, uint256 minClaimRateBips) external returns (uint256);
    function claimAll(address contractAddress, address recipient) external returns (uint256);
    function claimMax(address contractAddress, address recipient) external returns (uint256);
    function claim(address contractAddress, address recipient, uint256 gasToClaim, uint256 gasSecondsToConsume) external returns (uint256);
}

interface IYield {
    function configure(address contractAddress, uint8 flags) external returns (uint256);
    function claim(address contractAddress, address recipientOfYield, uint256 desiredAmount) external returns (uint256);
    function getClaimableAmount(address contractAddress) external view returns (uint256);
    function getConfiguration(address contractAddress) external view returns (uint8);
}

interface IBlast{
    // configure
    function configureContract(address contractAddress, YieldMode _yield, GasMode gasMode, address governor) external;
    function configure(YieldMode _yield, GasMode gasMode, address governor) external;

    // base configuration options
    function configureClaimableYield() external;
    function configureClaimableYieldOnBehalf(address contractAddress) external;
    function configureAutomaticYield() external;
    function configureAutomaticYieldOnBehalf(address contractAddress) external;
    function configureVoidYield() external;
    function configureVoidYieldOnBehalf(address contractAddress) external;
    function configureClaimableGas() external;
    function configureClaimableGasOnBehalf(address contractAddress) external;
    function configureVoidGas() external;
    function configureVoidGasOnBehalf(address contractAddress) external;
    function configureGovernor(address _governor) external;
    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external;

    // claim yield
    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external returns (uint256);
    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256);

    // claim gas
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256);
    // NOTE: can be off by 1 bip
    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips) external returns (uint256);
    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256);
    function claimGas(address contractAddress, address recipientOfGas, uint256 gasToClaim, uint256 gasSecondsToConsume) external returns (uint256);

    // read functions
    function readClaimableYield(address contractAddress) external view returns (uint256);
    function readYieldConfiguration(address contractAddress) external view returns (uint8);
    function readGasParams(address contractAddress) external view returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode);
    function isAuthorized(address contractAddress) external view returns (bool);
    function governorMap(address contractAddress) external view returns (address governor);
}