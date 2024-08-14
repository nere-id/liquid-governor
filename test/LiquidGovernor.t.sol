// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BlastMock} from "./mocks/BlastMock.sol";
import {YieldMode, GasMode, IBlast} from "../src/interfaces/IBlast.sol";
import {LiquidGovernor} from "../src/LiquidGovernor.sol";
import {DelegateToken} from "../src/DelegateToken.sol";

contract LiquidGovernorTest is Test {
    LiquidGovernor governor;
    DelegateToken delegate;
    address owner = makeAddr("owner");
    address vault = makeAddr("vault");
    address blast = 0x4300000000000000000000000000000000000002;

    function setUp() public {
        
    }
}
