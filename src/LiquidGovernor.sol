// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { ERC721 } from "../lib/solady/src/tokens/ERC721.sol";
import { Ownable } from "../lib/solady/src/auth/Ownable.sol";
import { YieldMode, GasMode, IGas, IBlast } from "./interfaces/IBlast.sol";
import { DelegateToken, DelegateConfig } from "./DelegateToken.sol";

contract LiquidGovernor is Ownable {
    IBlast constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    DelegateToken public delegateToken;        
    bool private _initialized;

    event DelegateCreated(
        uint256 tokenId, 
        address contractAddress, 
        address owner, 
        uint32 expiration
    );

    event ClaimProcessed(
        uint256 indexed tokenId,
        address indexed contractAddress, 
        address indexed to,         
        uint256 gasClaimed, 
        uint256 yieldClaimed
    );
    
    error InvalidDelegate();
    error DelegateIsActive(address contractAddress, uint32 tokenId);
    error UnauthorizedEarlyClaim();
    
    /**
     * @notice Initialize newly deployed LiquidGovernor clone.
     * @dev Can only be called once immediately following deployment.
     * @param _owner Account that will have admin control over LiquidGovernor.
     * @param _delegateToken The address of the delegate token contract.
     */
    function initialize(address _owner, address _delegateToken) external {
        require(!_initialized, "Already initialized");
        _initialized = true;
        _initializeOwner(_owner);
        delegateToken = DelegateToken(_delegateToken);        
    }    

    /**
     * @notice Freezes admin functions if there is an active delegate token
     */
    modifier onlyOwnerNoDelegate(address contractAddress) {
        uint32 tokenId = delegateToken.getDelegateId(contractAddress);
        if (tokenId != 0) revert DelegateIsActive(contractAddress, tokenId);
        _checkOwner();
        _;
    }

    /**
     * @notice Mint a new delegate token. Token holder can claim gas/yield at any point.
     * After expiration, anybody can process claim and burn the token.
     * @notice Only one delegate token can be minted per contractAddress at a time. 
     * @param to Recipient of newly minted token
     * @param contractAddress Contract that we are delegating gas/yield claims for
     * @param duration The duration of the claim period
     * @param gas True if we want to delegate gas fee claims
     * @param yield True if we want to delegate yield claims
     */
    function createDelegate(
        address to, 
        address contractAddress, 
        uint32 duration, 
        bool gas, 
        bool yield
    ) external onlyOwnerNoDelegate(contractAddress) {
        _forceClaimable(contractAddress, gas, yield);
        uint32 expiration = uint32(block.timestamp + duration);
        uint32 tokenId = delegateToken.mint(to, contractAddress, expiration, gas, yield);
        emit DelegateCreated(tokenId, contractAddress, to, expiration);
    }

    /**
     * @notice Claim gas/yield earnings and burn delegate token. This variant
     * Is meant to be called by token holder if they want to claim to alternative
     * address
     * @param contractAddress Contract we are claiming gas/yield from
     * @param to The recipient of claimed gas/yield 
     */
    function processClaim(address contractAddress, address to) external {
        _processClaim(contractAddress, to);
    }

    /**
     * @notice Process claim, sending claimed gas/yield to token holder and burn token
     * @param contractAddress Contract we are claiming gas/yield from
     */
    function processClaim(address contractAddress) external {
        _processClaim(contractAddress, address(0));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // Internal Functions
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Internal implementation to process claim and burn token
     * @param contractAddress Contract we are claiming gas/yield from
     * @param to The recipient of claimed gas/yield 
     */
    function _processClaim(address contractAddress, address to) internal {
        DelegateConfig memory config = delegateToken.getConfig(contractAddress);        
        if (config.tokenId == 0) revert InvalidDelegate();
        address owner = delegateToken.ownerOf(config.tokenId);
        // If msg.sender is not owner, ignore supplied `to` address
        address recipient = (to == address(0) || msg.sender != owner) ? owner : to;
        // Only token holder can make claim early
        if (config.expiration > block.timestamp && owner != msg.sender) 
            revert UnauthorizedEarlyClaim();                
        uint256 gasClaimed = config.canClaimGas ? _claimMaxGas(contractAddress, recipient) : 0;
        uint256 yieldClaimed = config.canClaimYield ? _claimAllYield(contractAddress, recipient) : 0;        
        delegateToken.burn(contractAddress);
        emit ClaimProcessed(config.tokenId, contractAddress, recipient, gasClaimed, yieldClaimed);
    }
    
    /**
     * @notice Force yield/gas mode to claimable. Used prior to minting delegate token.
     * @param contractAddress Contract address we are configuring gas/yield settings for
     * @param gas True if we plan to enable gas fee claims
     * @param yield True if we plan to enable yield fee claims
     */
    function _forceClaimable(address contractAddress, bool gas, bool yield) internal {
        (,,,GasMode gasMode) = BLAST.readGasParams(contractAddress);
        YieldMode yieldMode = YieldMode(BLAST.readYieldConfiguration(contractAddress));
        if (gas && gasMode != GasMode.CLAIMABLE) BLAST.configureClaimableGasOnBehalf(contractAddress);
        if (yield && yieldMode != YieldMode.CLAIMABLE) BLAST.configureClaimableYieldOnBehalf(contractAddress);
    }

    function _claimMaxGas(address contractAddress, address recipient) internal returns (uint256) {
        return BLAST.claimMaxGas(contractAddress, recipient);
    }

    function _claimAllYield(address contractAddress, address recipient) internal returns (uint256) {
        return BLAST.claimAllYield(contractAddress, recipient);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // Access Controlled Wrappers for Blast Predeploy
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // Configure //

    function configureContract(
        address contractAddress, 
        YieldMode _yield, 
        GasMode gasMode, 
        address 
        /**
         * @notice Modifier requiring t
         */ governor
    ) external onlyOwnerNoDelegate(contractAddress) {
        BLAST.configureContract(contractAddress, _yield, gasMode, governor);
    }

    function configureClaimableYieldOnBehalf(address contractAddress) external onlyOwnerNoDelegate(contractAddress) {
        BLAST.configureClaimableYieldOnBehalf(contractAddress);
    }    
    
    function configureAutomaticYieldOnBehalf(address contractAddress) external onlyOwnerNoDelegate(contractAddress) {
        BLAST.configureAutomaticYieldOnBehalf(contractAddress);
    }
    
    function configureVoidYieldOnBehalf(address contractAddress) external onlyOwnerNoDelegate(contractAddress) {
        BLAST.configureVoidYieldOnBehalf(contractAddress);
    }
    
    function configureClaimableGasOnBehalf(address contractAddress) external onlyOwnerNoDelegate(contractAddress) {
        BLAST.configureClaimableGasOnBehalf(contractAddress);
    }

    function configureVoidGasOnBehalf(address contractAddress) external onlyOwnerNoDelegate(contractAddress) {
        BLAST.configureVoidGasOnBehalf(contractAddress);
    }
    
    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external onlyOwnerNoDelegate(contractAddress) {
        BLAST.configureGovernorOnBehalf(_newGovernor, contractAddress);
    }

    // Claim Yield //

    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external onlyOwnerNoDelegate(contractAddress) returns (uint256) {
       return BLAST.claimYield(contractAddress, recipientOfYield, amount);
    }

    function claimAllYield(
        address contractAddress, 
        address recipientOfYield
    ) public onlyOwnerNoDelegate(contractAddress) returns (uint256) {
        return BLAST.claimAllYield(contractAddress, recipientOfYield);
    }

    // Claim Gas //

    function claimAllGas(
        address contractAddress, 
        address recipientOfGas
    ) external onlyOwnerNoDelegate(contractAddress) returns (uint256) {
        return BLAST.claimAllGas(contractAddress, recipientOfGas);
    }
    
    function claimGasAtMinClaimRate(
        address contractAddress, 
        address recipientOfGas, 
        uint256 minClaimRateBips
    ) external onlyOwnerNoDelegate(contractAddress) returns (uint256) {
        return BLAST.claimGasAtMinClaimRate(contractAddress, recipientOfGas, minClaimRateBips);
    }

    function claimMaxGas(
        address contractAddress, 
        address recipientOfGas
    ) public onlyOwnerNoDelegate(contractAddress) returns (uint256) {
        return BLAST.claimMaxGas(contractAddress, recipientOfGas);
    }

    function claimGas(
        address contractAddress, 
        address recipientOfGas, 
        uint256 gasToClaim, 
        uint256 gasSecondsToConsume
    ) external onlyOwnerNoDelegate(contractAddress) returns (uint256) {
        return BLAST.claimGas(contractAddress, recipientOfGas, gasToClaim, gasSecondsToConsume);
    }
}
