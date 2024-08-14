// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BlastMock} from "./mocks/BlastMock.sol";
import {VaultMock} from "./mocks/VaultMock.sol";
import {YieldMode, GasMode, IBlast} from "../src/interfaces/IBlast.sol";
import {LiquidGovernor} from "../src/LiquidGovernor.sol";
import {LiquidGovernorFactory} from "../src/LiquidGovernorFactory.sol";
import {DelegateConfig, DelegateToken} from "../src/DelegateToken.sol";

contract LiquidGovernorTest is Test {
    DelegateToken delegateToken;
    LiquidGovernorFactory factory;
    address implementation;
    LiquidGovernor vaultGovernor;
    IBlast constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    VaultMock vault;

    address owner = makeAddr("owner");
    address tokenHolder = makeAddr("tokenHolder");
    address rando = makeAddr("rando");

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

    error DelegateIsActive(address contractAddress, uint32 tokenId);
    error UnauthorizedEarlyClaim();
    
    modifier vaultGovSet() {
        vm.prank(owner);
        BLAST.configureGovernorOnBehalf(address(vaultGovernor), address(vault));
        _;
    }

    modifier vaultGovSetRando() {
        vm.prank(owner);
        BLAST.configureGovernorOnBehalf(rando, address(vault));
        _;
    }

    modifier delegateActive() {
        uint32 expiration = uint32(block.timestamp + 1 hours);        
        vm.prank(owner);
        vaultGovernor.createDelegate(
            tokenHolder,
            address(vault),
            1 hours,
            true, 
            true
        );
        _;
    }

    function setUp() public {
        implementation = address(new LiquidGovernor());
        factory = new LiquidGovernorFactory(implementation);
        delegateToken = DelegateToken(factory.delegateToken());
        
        // Deploy Mocks
        BlastMock blastMock = new BlastMock();
        vm.etch(0x4300000000000000000000000000000000000002, address(blastMock).code);
        vm.prank(owner);
        vault = new VaultMock();

        // Deploy new LiquidGovernor
        vm.prank(owner);
        vaultGovernor = LiquidGovernor(factory.deployGovernor(owner));
    }

    function test_setupWorks() public view {
        (,,,GasMode gasMode) = BLAST.readGasParams(address(vault));
        YieldMode yieldMode = YieldMode(BLAST.readYieldConfiguration(address(vault)));
        assertEq(uint8(gasMode), uint8(GasMode.VOID));
        assertEq(uint8(yieldMode), uint8(YieldMode.VOID));
        address currGovernor = BLAST.governorMap(address(vault));
        assertEq(currGovernor, owner);
        assertEq(owner, vaultGovernor.owner());
    }

    function test_vaultGovSetModifierWorks() public vaultGovSet {
        address currGovernor = BLAST.governorMap(address(vault));
        assertEq(currGovernor, address(vaultGovernor));
    }

    function test_reInitializationReverts() public vaultGovSet {
        vm.expectRevert(bytes("Already initialized"));
        vaultGovernor.initialize(owner, address(0));
        
        vm.expectRevert(bytes("Already initialized"));
        vm.prank(owner);
        vaultGovernor.initialize(owner, address(0));
    }

    function test_createDelegateReverts() public vaultGovSetRando {
        vm.expectRevert(bytes("not authorized to configure contract"));
        vm.prank(owner);
        vaultGovernor.createDelegate(
            tokenHolder,
            address(vault),
            1 hours,
            true, 
            true
        );
    }

    function test_createDelegateWorks() public vaultGovSet {        
        uint32 expiration = uint32(block.timestamp + 1 hours);
        vm.expectEmit(true, true, true, true);
        emit DelegateCreated(1, address(vault), tokenHolder, expiration);
        vm.prank(owner);
        vaultGovernor.createDelegate(
            tokenHolder,
            address(vault),
            1 hours,
            true, 
            true
        );

        DelegateConfig memory config = delegateToken.getConfig(address(vault));
        assertEq(config.tokenId, 1);
        assertEq(config.expiration, expiration);
        assertEq(config.canClaimGas, true);
        assertEq(config.canClaimYield, true);  
        assertEq(tokenHolder, delegateToken.ownerOf(1));
    }

    function test_createSecondDelegateReverts() public vaultGovSet delegateActive {
        vm.expectRevert(
            abi.encodeWithSelector(DelegateIsActive.selector, address(vault), 1)
        );
        vm.prank(owner);
        vaultGovernor.createDelegate(
            tokenHolder,
            address(vault),
            1 hours,
            true, 
            true
        );        
    }

    function test_delegatesOnMultipleContractsWorks() public vaultGovSet delegateActive {
        vm.startPrank(owner);
        VaultMock vault2 = new VaultMock();
        BLAST.configureGovernorOnBehalf(address(vaultGovernor), address(vault2));
        vm.stopPrank();

        uint32 expiration = uint32(block.timestamp + 1 hours);
        vm.expectEmit(true, true, true, true);
        emit DelegateCreated(2, address(vault2), tokenHolder, expiration);
        vm.prank(owner);
        vaultGovernor.createDelegate(
            tokenHolder,
            address(vault2),
            1 hours,
            true, 
            true
        );

        DelegateConfig memory config = delegateToken.getConfig(address(vault2));
        assertEq(config.tokenId, 2);
        assertEq(config.expiration, expiration);
        assertEq(config.canClaimGas, true);
        assertEq(config.canClaimYield, true);    

        assertEq(tokenHolder, delegateToken.ownerOf(2));    
    }

    function test_tokenHolderEarlyClaimWorks() public vaultGovSet delegateActive {
        DelegateConfig memory config = delegateToken.getConfig(address(vault));
        assertTrue(config.expiration > block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit ClaimProcessed(1, address(vault), tokenHolder, 0, 0);        
        vm.prank(tokenHolder);
        vaultGovernor.processClaim(address(vault));        
    }

    function test_tokenHolderClaimToWorks() public vaultGovSet delegateActive {
        DelegateConfig memory config = delegateToken.getConfig(address(vault));
        assertTrue(config.expiration > block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit ClaimProcessed(1, address(vault), rando, 0, 0);        
        vm.prank(tokenHolder);
        vaultGovernor.processClaim(address(vault), rando);   
    }

    function test_randoEarlyClaimReverts() public vaultGovSet delegateActive {
        DelegateConfig memory config = delegateToken.getConfig(address(vault));
        assertTrue(config.expiration > block.timestamp);
        vm.expectRevert(UnauthorizedEarlyClaim.selector);
        vm.prank(rando);
        vaultGovernor.processClaim(address(vault));        
    }

    function test_randoExpiredClaimWorks() public vaultGovSet delegateActive {
        vm.warp(block.timestamp + 2 hours);
        DelegateConfig memory config = delegateToken.getConfig(address(vault));        
        assertTrue(config.expiration <= block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit ClaimProcessed(1, address(vault), tokenHolder, 0, 0);        
        vm.prank(rando);
        vaultGovernor.processClaim(address(vault));   
    }

    function test_randoExpiredClaimToWorks() public vaultGovSet delegateActive {
        vm.warp(block.timestamp + 2 hours);
        DelegateConfig memory config = delegateToken.getConfig(address(vault));        
        assertTrue(config.expiration <= block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit ClaimProcessed(1, address(vault), tokenHolder, 0, 0);        
        vm.prank(rando);
        vaultGovernor.processClaim(address(vault), rando);   
    }
}
