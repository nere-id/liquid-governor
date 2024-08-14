// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { ERC721 } from "../lib/solady/src/tokens/ERC721.sol";
import { LibString } from "../lib/solady/src/utils/LibString.sol";
import { IBlast } from "./interfaces/IBlast.sol";
import {ILiquidGovernorFactory} from "./interfaces/ILiquidGovernorFactory.sol";

struct DelegateConfig {    
    uint32 tokenId;    
    uint64 expiration;    
    bool canClaimGas;
    bool canClaimYield;        
}

contract DelegateToken is ERC721 {
    using LibString for uint256;

    IBlast constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    ILiquidGovernorFactory private immutable _factory;
    uint32 private nextTokenId = 1;    
    mapping(address contractAddress => DelegateConfig delegate) public configs;    

    error Unauthorized();
    error ActiveDelegateExists();
    error UnprocessedClaimExists();
    error DelegateNotExpired();    
    error InvalidDelegate(); 

    constructor(address factory) {
        _factory = ILiquidGovernorFactory(factory);
    }

    function name() public pure override returns (string memory) {
        return "Liquid Governor Delegate";
    }

    function symbol() public pure override returns (string memory) {
        return "LGD";
    }

    function tokenURI(uint256 id) public pure override returns (string memory) {
        return string.concat("meh/", id.toString());
    }

    modifier onlyDelegateOwner(uint256 tokenId) {
        if (msg.sender != ownerOf(tokenId)) revert Unauthorized();                    
        _;
    }

    /**
     * @notice msg.sender must (a) configured governor and (b) deployed from expected factory.
     * @param contractAddress the contract that we expect msg.sender to be the governor of.
     */
    modifier onlyLiquidGovernor(address contractAddress) {
        address governor = BLAST.governorMap(contractAddress);
        bool isLiquid = _factory.isLiquidGovernor(governor);
        if (msg.sender != governor || !isLiquid) revert Unauthorized();        
        _;
    }    

    /**
     * @param contractAddress The contract that we want the token id for.
     * @return tokenId Id of the delegate token for contractAddress. Returns 0 if no token exists.
     */
    function getDelegateId(address contractAddress) external view returns (uint32 tokenId) {        
        return configs[contractAddress].tokenId;
    }

    /**
     * @param contractAddress The contract that we want the config for.
     * @return config The current delegate configuration for contractAddress
     */
    function getConfig(address contractAddress) external view returns (DelegateConfig memory config) {
        return configs[contractAddress];
    }

    /**
     * @notice Mint an NFT (Delegate) that will delegate gas and/or ETH yield claims up until `expiration`
     * @notice Each contract can only have a single active delegate NFT in circulation at a time     
     * @param to the address that the token will be minted to
     * @param contractAddress the contract from which gas and/or yield will be claimed
     * @param expiration timestamp of when the NFT's ability to claim will expire
     * @param canClaimGas true if NFT should allow gas fees to be claimed
     * @param canClaimYield true if NFT should allow ETH yield to be claimed
     * @return tokenId id of the minted NFT
     */
    function mint(
        address to, 
        address contractAddress, 
        uint32 expiration, 
        bool canClaimGas, 
        bool canClaimYield
    ) external onlyLiquidGovernor(contractAddress) returns (uint32 tokenId)  {        
        DelegateConfig memory config = configs[contractAddress];        
        if (config.expiration > block.timestamp) revert ActiveDelegateExists();
        if (config.tokenId != 0) revert UnprocessedClaimExists();
        tokenId = nextTokenId++;
        config.tokenId = uint32(tokenId);
        config.expiration = expiration;
        config.canClaimGas = canClaimGas;
        config.canClaimYield = canClaimYield;
        configs[contractAddress] = config;
        _mint(to, tokenId);
    }        

    /**
     * @notice Destroy the delegate token for contractAddress. Must be called by LiquidGovernor.
     * @param contractAddress The contract for which the corresponding delegate token should be destroyed.
     */
    function burn(address contractAddress) onlyLiquidGovernor(contractAddress) external {        
        DelegateConfig memory config = configs[contractAddress];          
        uint256 tokenId = config.tokenId; 
        delete configs[contractAddress];
        _burn(tokenId);
    }
}