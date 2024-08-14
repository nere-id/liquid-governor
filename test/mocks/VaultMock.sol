// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {YieldMode, GasMode, IBlast} from "../../src/interfaces/IBlast.sol";

contract VaultMock {
    IBlast constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    constructor() {
        BLAST.configure(YieldMode.VOID, GasMode.VOID, msg.sender);
    }

    receive() external payable {}
}