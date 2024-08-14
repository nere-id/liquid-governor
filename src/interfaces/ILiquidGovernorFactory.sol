// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface ILiquidGovernorFactory {
    function isLiquidGovernor(address contractAddress) external returns (bool);
}