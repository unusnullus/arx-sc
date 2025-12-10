// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {ARX} from "../src/token/ARX.sol";
import {ArxTokenSale} from "../src/sale/ArxTokenSale.sol";
import {
    ArxZapRouter,
    IWETH9,
    ISwapRouter,
    IArxTokenSale
} from "../src/zap/ArxZapRouter.sol";
import {ArxTimelock} from "../src/governance/ArxTimelock.sol";
import {ArxGovernor} from "../src/governance/ArxGovernor.sol";
import {StakingAccess} from "../src/services/StakingAccess.sol";
import {
    ServiceRegistry,
    IStakingAccess
} from "../src/services/ServiceRegistry.sol";
import {
    ArxMultiTokenMerkleClaim
} from "../src/claimable/ArxMultiTokenMerkleClaim.sol";
import {ARXPool} from "../src/pool/ARXPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {
    TimelockControllerUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {ERC1967Proxy} from "../src/proxy/ERC1967Proxy.sol";

/// @title DeploySepoliaFull
/// @notice Complete deployment script for full ARX ecosystem on Sepolia testnet.
/// @dev Deploys all contracts: token, sale, zap, governance, services, claims.
contract DeploySepoliaFull is Script {
    function run() external {
        // Private key is passed via --private-key flag, so we use startBroadcast() without params
        // This automatically uses the private key from the command line
        vm.startBroadcast();
        address deployer = msg.sender;

        // Core environment variables
        address usdc = vm.envAddress("USDC");
        address owner = vm.envOr("OWNER", deployer);
        address silo = vm.envOr("SILO_TREASURY", owner);
        uint256 price = vm.envOr("ARX_PRICE_USDC_6DP", uint256(1_000_000)); // 1 USDC default

        // Optional zap router variables (can skip if not needed)
        address weth9 = vm.envOr("WETH9", address(0));
        address swapRouter = vm.envOr("UNISWAP_V3_SWAPROUTER", address(0));
        address uniswapV2Router = vm.envOr("UNISWAP_V2_ROUTER", address(0));

        // Governance parameters
        uint256 timelockDelay = vm.envOr("TIMELOCK_DELAY", uint256(3600)); // 1h
        uint256 govQuorum = vm.envOr("GOV_QUORUM_PERCENT", uint256(4)); // 4%
        uint256 votingDelay = vm.envOr("GOV_VOTING_DELAY", uint256(1)); // 1 block
        uint256 votingPeriod = vm.envOr("GOV_VOTING_PERIOD", uint256(45818)); // ~1 week

        console.log("=== Deploying Full ARX Ecosystem to Sepolia ===");
        console.log("Deployer:", deployer);
        console.log("Owner:", owner);
        console.log("USDC:", usdc);
        console.log("Silo:", silo);
        console.log("Price (6dp):", price);

        // ==================== 1. Deploy ARX Token ====================
        console.log("\n--- Deploying ARX Token ---");
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(
            ARX.initialize.selector,
            deployer,
            address(0), // tokenSale - set later
            uniswapV2Router,
            usdc,
            weth9
        );
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        ARX arx = ARX(address(arxProxy));
        console.log("ARX Implementation:", address(arxImpl));
        console.log("ARX Proxy:", address(arx));

        // ==================== 2. Deploy ArxTokenSale ====================
        console.log("\n--- Deploying ArxTokenSale ---");
        ArxTokenSale saleImpl = new ArxTokenSale();
        bytes memory dataSale = abi.encodeWithSelector(
            ArxTokenSale.initialize.selector,
            deployer,
            IERC20(usdc),
            arx,
            silo,
            price
        );
        ERC1967Proxy saleProxy = new ERC1967Proxy(address(saleImpl), dataSale);
        ArxTokenSale sale = ArxTokenSale(address(saleProxy));
        console.log("Sale Implementation:", address(saleImpl));
        console.log("Sale Proxy:", address(sale));

        // Grant MINTER_ROLE and set tokenSale in ARX
        console.log("\n--- Granting MINTER_ROLE to Sale ---");
        arx.grantRole(arx.MINTER_ROLE(), address(sale));
        console.log("MINTER_ROLE granted to:", address(sale));
        console.log("\n--- Setting TokenSale in ARX ---");
        arx.setTokenSale(address(sale));
        console.log("TokenSale set to:", address(sale));

        // ==================== 3. Deploy ARXPool ====================
        console.log("\n--- Deploying ARXPool ---");
        ARXPool poolImpl = new ARXPool();
        bytes memory dataPool = abi.encodeWithSelector(
            ARXPool.initialize.selector,
            address(arx),
            usdc,
            owner
        );
        ERC1967Proxy poolProxy = new ERC1967Proxy(address(poolImpl), dataPool);
        ARXPool pool = ARXPool(address(poolProxy));
        console.log("Pool Implementation:", address(poolImpl));
        console.log("Pool Proxy:", address(pool));

        // ==================== 4. Deploy ArxZapRouter (Optional) ====================
        ArxZapRouter zap;
        ArxZapRouter zapImpl;
        bytes memory dataZap;
        if (weth9 != address(0) && swapRouter != address(0)) {
            console.log("\n--- Deploying ArxZapRouter ---");
            zapImpl = new ArxZapRouter();
            dataZap = abi.encodeWithSelector(
                ArxZapRouter.initialize.selector,
                deployer,
                IERC20(usdc),
                IWETH9(weth9),
                ISwapRouter(swapRouter)
            );
            ERC1967Proxy zapProxy = new ERC1967Proxy(address(zapImpl), dataZap);
            zap = ArxZapRouter(payable(address(zapProxy)));
            console.log("Zap Implementation:", address(zapImpl));
            console.log("Zap Proxy:", address(zap));

            // Wire permissions
            console.log("\n--- Wiring Zap Permissions ---");
            zap.setSale(address(sale));
            console.log("Zap sale set to:", address(sale));
            sale.setZapper(address(zap), true);
            console.log("Zap authorized in sale:", address(zap));
        } else {
            console.log(
                "\n--- Skipping ArxZapRouter (WETH9/SWAPROUTER not set) ---"
            );
        }

        // ==================== 5. Deploy ArxTimelock ====================
        console.log("\n--- Deploying ArxTimelock ---");
        ArxTimelock timelockImpl = new ArxTimelock();
        address[] memory proposers = new address[](1);
        proposers[0] = owner;
        address[] memory executors = new address[](1);
        executors[0] = owner;
        // Use deployer as admin initially so we can grant roles, then transfer to owner later
        bytes memory dataTL = abi.encodeWithSelector(
            ArxTimelock.initialize.selector,
            timelockDelay,
            proposers,
            executors,
            deployer
        );
        ERC1967Proxy timelockProxy = new ERC1967Proxy(
            address(timelockImpl),
            dataTL
        );
        ArxTimelock timelock = ArxTimelock(payable(address(timelockProxy)));
        console.log("Timelock Implementation:", address(timelockImpl));
        console.log("Timelock Proxy:", address(timelock));

        // ==================== 6. Deploy ArxGovernor ====================
        console.log("\n--- Deploying ArxGovernor ---");
        ArxGovernor governorImpl = new ArxGovernor();
        bytes memory dataGov = abi.encodeWithSelector(
            ArxGovernor.initialize.selector,
            IVotes(address(arx)),
            TimelockControllerUpgradeable(payable(address(timelock))),
            govQuorum,
            votingDelay,
            votingPeriod
        );
        ERC1967Proxy governorProxy = new ERC1967Proxy(
            address(governorImpl),
            dataGov
        );
        ArxGovernor governor = ArxGovernor(payable(address(governorProxy)));
        console.log("Governor Implementation:", address(governorImpl));
        console.log("Governor Proxy:", address(governor));

        // ==================== 7. Wire Timelock Roles to Governor ====================
        console.log("\n--- Wiring Timelock Roles ---");
        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

        // Grant roles to governor (deployer has admin role from initialization)
        timelock.grantRole(PROPOSER_ROLE, address(governor));
        console.log("PROPOSER_ROLE granted to Governor");
        timelock.grantRole(EXECUTOR_ROLE, address(governor));
        console.log("EXECUTOR_ROLE granted to Governor");

        // Transfer admin role to owner if different from deployer
        if (owner != deployer) {
            timelock.grantRole(ADMIN_ROLE, owner);
            timelock.revokeRole(ADMIN_ROLE, deployer);
            console.log("ADMIN_ROLE transferred to owner");
        }

        // ==================== 8. Deploy StakingAccess ====================
        console.log("\n--- Deploying StakingAccess ---");
        StakingAccess stakingImpl = new StakingAccess();
        uint256[] memory tiers = new uint256[](3);
        tiers[0] = 1_000_000; // 1 ARX (6 decimals)
        tiers[1] = 10_000_000; // 10 ARX
        tiers[2] = 100_000_000; // 100 ARX
        bytes memory dataStaking = abi.encodeWithSelector(
            StakingAccess.initialize.selector,
            IERC20(address(arx)),
            address(timelock),
            tiers
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(
            address(stakingImpl),
            dataStaking
        );
        StakingAccess staking = StakingAccess(address(stakingProxy));
        console.log("Staking Implementation:", address(stakingImpl));
        console.log("Staking Proxy:", address(staking));

        // ==================== 9. Deploy ServiceRegistry ====================
        console.log("\n--- Deploying ServiceRegistry ---");
        ServiceRegistry registryImpl = new ServiceRegistry();
        bytes memory dataRegistry = abi.encodeWithSelector(
            ServiceRegistry.initialize.selector,
            IStakingAccess(address(staking)),
            address(timelock)
        );
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            dataRegistry
        );
        ServiceRegistry registry = ServiceRegistry(address(registryProxy));
        console.log("Registry Implementation:", address(registryImpl));
        console.log("Registry Proxy:", address(registry));

        // ==================== 10. Deploy ArxMultiTokenMerkleClaim ====================
        console.log("\n--- Deploying ArxMultiTokenMerkleClaim ---");
        ArxMultiTokenMerkleClaim claimImpl = new ArxMultiTokenMerkleClaim();
        bytes memory dataClaim = abi.encodeWithSelector(
            ArxMultiTokenMerkleClaim.initialize.selector,
            address(timelock)
        );
        ERC1967Proxy claimProxy = new ERC1967Proxy(
            address(claimImpl),
            dataClaim
        );
        ArxMultiTokenMerkleClaim claim = ArxMultiTokenMerkleClaim(
            address(claimProxy)
        );
        console.log("Claim Implementation:", address(claimImpl));
        console.log("Claim Proxy:", address(claim));

        vm.stopBroadcast();

        // ==================== Summary ====================
        console.log("\n=== Deployment Summary ===");
        console.log("ARX Proxy:", address(arx));
        console.log("ArxTokenSale Proxy:", address(sale));
        console.log("ARXPool Proxy:", address(pool));
        if (address(zap) != address(0)) {
            console.log("ArxZapRouter Proxy:", address(zap));
        }
        console.log("ArxTimelock Proxy:", address(timelock));
        console.log("ArxGovernor Proxy:", address(governor));
        console.log("StakingAccess Proxy:", address(staking));
        console.log("ServiceRegistry Proxy:", address(registry));
        console.log("ArxMultiTokenMerkleClaim Proxy:", address(claim));
        console.log("\nDeployment complete!");

        // Also output in format for easy parsing
        console.log("\n=== Addresses for .env.sepolia ===");
        console.log("ARX:", address(arx));
        console.log("ArxTokenSale:", address(sale));
        console.log("ARXPool:", address(pool));
        if (address(zap) != address(0)) {
            console.log("ArxZapRouter:", address(zap));
        }
        console.log("ArxTimelock:", address(timelock));
        console.log("ArxGovernor:", address(governor));
        console.log("StakingAccess:", address(staking));
        console.log("ServiceRegistry:", address(registry));
        console.log("ArxMultiTokenMerkleClaim:", address(claim));

        // Output implementation addresses and initialization data for proxy verification
        console.log("\n=== Implementation Addresses (for verification) ===");
        console.log("ARX_IMPL:", address(arxImpl));
        console.log("ARX_INIT_DATA:", vm.toString(dataArx));
        console.log("SALE_IMPL:", address(saleImpl));
        console.log("SALE_INIT_DATA:", vm.toString(dataSale));
        console.log("POOL_IMPL:", address(poolImpl));
        console.log("POOL_INIT_DATA:", vm.toString(dataPool));
        if (address(zap) != address(0) && address(zapImpl) != address(0)) {
            console.log("ZAP_IMPL:", address(zapImpl));
            console.log("ZAP_INIT_DATA:", vm.toString(dataZap));
        }
        console.log("TIMELOCK_IMPL:", address(timelockImpl));
        console.log("TIMELOCK_INIT_DATA:", vm.toString(dataTL));
        console.log("GOVERNOR_IMPL:", address(governorImpl));
        console.log("GOVERNOR_INIT_DATA:", vm.toString(dataGov));
        console.log("STAKING_IMPL:", address(stakingImpl));
        console.log("STAKING_INIT_DATA:", vm.toString(dataStaking));
        console.log("REGISTRY_IMPL:", address(registryImpl));
        console.log("REGISTRY_INIT_DATA:", vm.toString(dataRegistry));
        console.log("CLAIM_IMPL:", address(claimImpl));
        console.log("CLAIM_INIT_DATA:", vm.toString(dataClaim));

        // Output for .env.sepolia file
        console.log("\n=== .env.sepolia Content ===");
        console.log("NEXT_PUBLIC_CHAIN_ID=11155111");
        console.log("NEXT_PUBLIC_ARX=", vm.toString(address(arx)));
        console.log("NEXT_PUBLIC_ARX_TOKEN_SALE=", vm.toString(address(sale)));
        console.log("NEXT_PUBLIC_ARX_POOL=", vm.toString(address(pool)));
        if (address(zap) != address(0)) {
            console.log(
                "NEXT_PUBLIC_ARX_ZAP_ROUTER=",
                vm.toString(address(zap))
            );
        }
        console.log("NEXT_PUBLIC_USDC=", vm.toString(usdc));
        console.log("NEXT_PUBLIC_SILO_TREASURY=", vm.toString(silo));
        console.log(
            "NEXT_PUBLIC_ARX_TIMELOCK=",
            vm.toString(address(timelock))
        );
        console.log(
            "NEXT_PUBLIC_ARX_GOVERNOR=",
            vm.toString(address(governor))
        );
        console.log(
            "NEXT_PUBLIC_STAKING_ACCESS=",
            vm.toString(address(staking))
        );
        console.log(
            "NEXT_PUBLIC_SERVICE_REGISTRY=",
            vm.toString(address(registry))
        );
        console.log("NEXT_PUBLIC_ARX_CLAIM=", vm.toString(address(claim)));
    }
}
