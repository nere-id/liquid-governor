// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BlastMock} from "./mocks/BlastMock.sol";
import {YieldMode, GasMode, IBlast} from "../src/interfaces/IBlast.sol";
import {LiquidGovernor} from "../src/LiquidGovernor.sol";
import {DelegateToken} from "../src/DelegateToken.sol";

contract BlastMockTest is Test {
    function setUp() public {
        BlastMock blastMock = new BlastMock();
        vm.etch(0x4300000000000000000000000000000000000002, address(blastMock).code);
    }

    
}