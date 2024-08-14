// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import { YieldMode, GasMode, IBlast } from "../../src/interfaces/IBlast.sol";

contract BlastMock is IBlast {
    address public immutable YIELD_CONTRACT;
    address public immutable GAS_CONTRACT;

    mapping(address => address) public governorMap;
    mapping(address => GasMode) public gasModeMap;
    mapping(address => YieldMode) public yieldModeMap;
    
    function setGasMode(address who, GasMode gasMode) public {
        gasModeMap[who] = gasMode;
    }

    function configure(address who, YieldMode yieldMode) public {
        yieldModeMap[who] = yieldMode;
    }
    
    function isGovernor(address contractAddress) public view returns (bool) {
        return msg.sender == governorMap[contractAddress];
    }
    
    function governorNotSet(address contractAddress) internal view returns (bool) {
        return governorMap[contractAddress] == address(0);
    }

    function isAuthorized(address contractAddress) public view returns (bool) {
        return isGovernor(contractAddress) || (governorNotSet(contractAddress) && msg.sender == contractAddress);
    }

    function configure(YieldMode _yieldMode, GasMode _gasMode, address governor) external {
        // requires that no governor is set for contract
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        // set governor
        governorMap[msg.sender] = governor;
        // set gas mode
        setGasMode(msg.sender, _gasMode);
        // set yield mode
        configure(msg.sender, _yieldMode);
    }

    function configureContract(address contractAddress, YieldMode _yieldMode, GasMode _gasMode, address _newGovernor) external {
        // only allow governor, or if no governor is set, the contract itself to configure
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        // set governor
        governorMap[contractAddress] = _newGovernor;
        // set gas mode
        setGasMode(contractAddress, _gasMode);
        // set yield mode
        configure(contractAddress, _yieldMode);
    }

    function configureClaimableYield() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        configure(msg.sender, YieldMode.CLAIMABLE);
    }

    function configureClaimableYieldOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        configure(contractAddress, YieldMode.CLAIMABLE);
    }

    function configureAutomaticYield() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        configure(msg.sender, YieldMode.AUTOMATIC);
    }

    function configureAutomaticYieldOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        configure(contractAddress, YieldMode.AUTOMATIC);
    }

    function configureVoidYield() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        configure(msg.sender, YieldMode.VOID);
    }

    function configureVoidYieldOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        configure(contractAddress, YieldMode.VOID);
    }

    function configureClaimableGas() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        setGasMode(msg.sender, GasMode.CLAIMABLE);
    }

    function configureClaimableGasOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        setGasMode(contractAddress, GasMode.CLAIMABLE);
    }

    function configureVoidGas() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        setGasMode(msg.sender, GasMode.VOID);
    }

    function configureVoidGasOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        setGasMode(contractAddress, GasMode.VOID);
    }

    function configureGovernor(address _governor) external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        governorMap[msg.sender] = _governor;
    }

    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        governorMap[contractAddress] = _newGovernor;
    }


    // claim methods

    function claimYield(address contractAddress, address /* recipientOfYield */, uint256 /* amount */) external view returns (uint256) {
        require(isAuthorized(contractAddress), "Not authorized to claim yield");
        console.log("Yield Claimed (claimYield)");
        return 0;
    }

    function claimAllYield(address contractAddress, address /* recipientOfYield */) external view returns (uint256) {
        require(isAuthorized(contractAddress), "Not authorized to claim yield");        
        console.log("Yield claimed (claimAllYield)");
        return 0;
    }

    function claimAllGas(address contractAddress, address /* recipientOfGas */) external view returns (uint256) {
        require(isAuthorized(contractAddress), "Not allowed to claim all gas");  
        console.log("Gas Claimed (claimAllGas)");
        return 0;
    }

    function claimGasAtMinClaimRate(address contractAddress, address /* recipientOfGas */, uint256 /* minClaimRateBips */) external view returns (uint256) {
        require(isAuthorized(contractAddress), "Not allowed to claim gas at min claim rate");        
        console.log("Gas Claimed (claimGasAtMinClaimRate)");
        return 0;
    }
    function claimMaxGas(address contractAddress, address /* recipientOfGas */) external view returns (uint256) {
        require(isAuthorized(contractAddress), "Not allowed to claim max gas");        
        console.log("Gas Claimed (claimMaxGas)");
        return 0;
    }
    
    function claimGas(address contractAddress, address /* recipientOfGas */, uint256 /* gasToClaim */, uint256 /* gasSecondsToConsume */) external view returns (uint256) {
        require(isAuthorized(contractAddress), "Not allowed to claim gas");
        console.log("Gas Claimed (claimGas)");
        return 0;
    }

    function readClaimableYield(address /* contractAddress */) public pure returns (uint256) {
        return 0;
    }

    function readYieldConfiguration(address contractAddress) public view returns (uint8) {
        return uint8(yieldModeMap[contractAddress]);
    }

    function readGasParams(address contractAddress) public view returns (uint256, uint256, uint256, GasMode) {
        return (0, 0, 0, gasModeMap[contractAddress]);
    }
}