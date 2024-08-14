// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { ERC721 } from "../lib/solady/src/tokens/ERC721.sol";
import { Ownable } from "../lib/solady/src/auth/Ownable.sol";
import { YieldMode, GasMode, IGas, IBlast } from "./interfaces/IBlast.sol";
import { DelegateToken, DelegateConfig } from "./DelegateToken.sol";

contract LiquidGovernor is Ownable {
    IBlast constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    DelegateToken public delegateToken;    
    uint256 public activeDelegateId;

    event DelegateCreated(
        uint256 tokenId, 
        address contractAddress, 
        address owner, 
        uint32 expiration
    );

    event DelegateClaimProcessed(
        uint256 indexed tokenId,
        address indexed contractAddress, 
        address indexed to,         
        uint256 gasClaimed, 
        uint256 yieldClaimed
    );

    error NotOwnerOrDelegate();
    error InvalidDelegate();
    error DelegateIsActive();
    error UnauthorizedEarlyClaim();
    
    function initialize(address _owner, address _delegateToken) external {
        _initializeOwner(_owner);
        delegateToken = DelegateToken(_delegateToken);
    }    

    modifier onlyOwnerWithoutDelegate() {
        if (activeDelegateId != 0) revert DelegateIsActive();
        _checkOwner();
        _;
    }

    function createDelegate(
        address to, 
        address contractAddress, 
        uint32 duration, 
        bool gas, 
        bool yield
    ) external onlyOwner {
        _forceClaimable(contractAddress, gas, yield);
        uint32 expiration = uint32(block.timestamp + duration);
        uint32 tokenId = delegateToken.mint(to, contractAddress, expiration, gas, yield);
        emit DelegateCreated(tokenId, contractAddress, to, expiration);
    }

    function processClaim(address contractAddress, address to) external {
        _processClaim(contractAddress, to);
    }

    function processClaim(address contractAddress) external {
        _processClaim(contractAddress, address(0));
    }

    function _processClaim(address contractAddress, address to) internal {
        DelegateConfig memory config = delegateToken.getConfig(contractAddress);        
        if (config.tokenId == 0) revert InvalidDelegate();
        address owner = delegateToken.ownerOf(config.tokenId);
        address recipient = to == address(0) ? owner : to;
        // Only token holder can make claim early
        if (config.expiration > block.timestamp && owner != msg.sender) 
            revert UnauthorizedEarlyClaim();                
        uint256 gasClaimed = config.canClaimGas ? claimMaxGas(contractAddress, recipient) : 0;
        uint256 yieldClaimed = config.canClaimYield ? claimAllYield(contractAddress, recipient) : 0;        
        delegateToken.burn(contractAddress);
        emit DelegateClaimProcessed(config.tokenId, contractAddress, recipient, gasClaimed, yieldClaimed);
    }

    function _forceClaimable(address contractAddress, bool gas, bool yield) internal {
        (,,,GasMode gasMode) = BLAST.readGasParams(contractAddress);
        YieldMode yieldMode = YieldMode(BLAST.readYieldConfiguration(contractAddress));
        if (gas && gasMode != GasMode.CLAIMABLE) BLAST.configureClaimableGasOnBehalf(contractAddress);
        if (yield && yieldMode != YieldMode.CLAIMABLE) BLAST.configureClaimableYieldOnBehalf(contractAddress);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // Access Controlled Wrappers for Blast Predeploy
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // Configure //

    function configureContract(
        address contractAddress, 
        YieldMode _yield, 
        GasMode gasMode, 
        address governor
    ) external onlyOwnerWithoutDelegate {
        BLAST.configureContract(contractAddress, _yield, gasMode, governor);
    }

    function configureClaimableYield() external onlyOwnerWithoutDelegate {
        BLAST.configureClaimableYield();
    }

    function configureClaimableYieldOnBehalf(address contractAddress) external onlyOwnerWithoutDelegate {
        BLAST.configureClaimableYieldOnBehalf(contractAddress);
    }    
    
    function configureAutomaticYieldOnBehalf(address contractAddress) external onlyOwnerWithoutDelegate {
        BLAST.configureAutomaticYieldOnBehalf(contractAddress);
    }
    
    function configureVoidYieldOnBehalf(address contractAddress) external onlyOwnerWithoutDelegate {
        BLAST.configureVoidYieldOnBehalf(contractAddress);
    }
    
    function configureClaimableGasOnBehalf(address contractAddress) external onlyOwnerWithoutDelegate {
        BLAST.configureClaimableGasOnBehalf(contractAddress);
    }

    function configureVoidGasOnBehalf(address contractAddress) external onlyOwnerWithoutDelegate {
        BLAST.configureVoidGasOnBehalf(contractAddress);
    }
    
    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external onlyOwnerWithoutDelegate {
        BLAST.configureGovernorOnBehalf(_newGovernor, contractAddress);
    }

    // Claim Yield //

    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external onlyOwnerWithoutDelegate returns (uint256) {
       return BLAST.claimYield(contractAddress, recipientOfYield, amount);
    }

    function claimAllYield(
        address contractAddress, 
        address recipientOfYield
    ) public onlyOwnerWithoutDelegate returns (uint256) {
        return BLAST.claimAllYield(contractAddress, recipientOfYield);
    }

    // Claim Gas //

    function claimAllGas(
        address contractAddress, 
        address recipientOfGas
    ) external onlyOwnerWithoutDelegate returns (uint256) {
        return BLAST.claimAllGas(contractAddress, recipientOfGas);
    }
    
    function claimGasAtMinClaimRate(
        address contractAddress, 
        address recipientOfGas, 
        uint256 minClaimRateBips
    ) external onlyOwnerWithoutDelegate returns (uint256) {
        return BLAST.claimGasAtMinClaimRate(contractAddress, recipientOfGas, minClaimRateBips);
    }

    function claimMaxGas(
        address contractAddress, 
        address recipientOfGas
    ) public onlyOwnerWithoutDelegate returns (uint256) {
        return BLAST.claimMaxGas(contractAddress, recipientOfGas);
    }

    function claimGas(
        address contractAddress, 
        address recipientOfGas, 
        uint256 gasToClaim, 
        uint256 gasSecondsToConsume
    ) external onlyOwnerWithoutDelegate returns (uint256) {
        return BLAST.claimGas(contractAddress, recipientOfGas, gasToClaim, gasSecondsToConsume);
    }
}
