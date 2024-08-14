// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { IERC721 } from "forge-std/interfaces/IERC721.sol";

interface IDelegateToken is IERC721 {
    function getDelegateId(address contractAddress) external view returns (uint256);
}