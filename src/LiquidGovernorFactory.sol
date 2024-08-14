// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {LibClone} from "../lib/solady/src/utils/LibClone.sol";
import {LiquidGovernor} from "./LiquidGovernor.sol";
import {DelegateToken} from "./DelegateToken.sol";

contract LiquidGovernorFactory {
    using LibClone for address;

    event LiquidGovernorDeployed(address indexed owner, address indexed governor);

    address public immutable implementation;
    address public immutable delegateToken;
    mapping(address => bool) public isLiquidGovernor;

    constructor(address _implementation) {
        implementation = _implementation;
        delegateToken = address(new DelegateToken(address(this)));
    }

    /**
     * @notice Deploy a new LiquidGovernor. The newly deployed LiquidGovernor must
     * be set as the governor of desired contract(s) through the Blast predeploy
     * before a delegate token can be minted.
     * @param owner The account that should have admin controls over the LiquidDelegate
     * @return governor Address of newly deployed LiquidGovernor
     */
    function deployGovernor(address owner) external returns (address governor) {
        governor = implementation.clone();
        isLiquidGovernor[governor] = true;
        LiquidGovernor(governor).initialize(owner, delegateToken);
        emit LiquidGovernorDeployed(owner, governor);
    }
}