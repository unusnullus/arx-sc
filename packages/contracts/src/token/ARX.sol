// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    NoncesUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IARX} from "./IARX.sol";

/// @notice Uniswap V2 Router interface for price queries
interface IUniswapV2Router02 {
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

/// @notice Minimal interface to interact with the ARX token sale contract
interface IArxTokenSale {
    /// @notice Returns the USDC token contract used by the sale
    function USDC() external view returns (IERC20);
    /// @notice Returns the price of ARX in USDC (6 decimals per 1e18 ARX)
    function priceUSDC() external view returns (uint256);
    /// @notice Returns the decimals of ARX token
    function arxDecimals() external view returns (uint8);
}

/// @title ARX Token
/// @notice ERC20 governance/utility token for the ARX ecosystem.
/// @dev Includes ERC20Permit for gasless approvals, burnable extension,
///      AccessControl to gate minting (MINTER_ROLE), and ERC20Votes for governance.
// IARX interface moved to ./token/IARX.sol

/// @title ARX ERC20 Implementation
/// @notice Minimal ERC20 with permit, votes and controlled minting via roles.
contract ARX is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IARX
{
    /// @notice Role identifier allowed to call {mint}.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Maximum supply cap to prevent unlimited inflation (1 billion ARX).
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 6;

    /// @notice Total amount minted (for max supply enforcement).
    uint256 public totalMinted;

    /// @notice ARX token sale contract for price calculations
    IArxTokenSale public tokenSale;

    /// @notice Uniswap V2 router for token swaps and price queries
    IUniswapV2Router02 public uniswapRouter;

    /// @notice USDC token contract for price calculations
    IERC20 public usdcToken;

    /// @notice WETH token address for ETH price calculations
    address public wethToken;

    error ZeroAddress();
    error ZeroAmount();
    error MaxSupplyExceeded();
    error InvalidAddress();
    error InvalidAmount();
    error PriceContractsNotInitialized();

    event TokenSaleUpdated(address indexed previous, address indexed current);
    event UniswapRouterUpdated(
        address indexed previous,
        address indexed current
    );
    event UsdcTokenUpdated(address indexed previous, address indexed current);
    event WethTokenUpdated(address indexed previous, address indexed current);

    /// @notice Initialize proxy instance.
    /// @param admin Address that receives DEFAULT_ADMIN_ROLE and controls roles.
    /// @param _tokenSale Address of the ARX token sale contract (can be address(0) to set later)
    /// @param _uniswapRouter Address of Uniswap V2 router (can be address(0) to set later)
    /// @param _usdcToken Address of USDC token (can be address(0) to set later)
    /// @param _wethToken Address of WETH token (can be address(0) to set later)
    function initialize(
        address admin,
        address _tokenSale,
        address _uniswapRouter,
        address _usdcToken,
        address _wethToken
    ) public initializer {
        if (admin == address(0)) revert ZeroAddress();

        __ERC20_init("ARX NET Slice", "ARX");
        __ERC20Burnable_init();
        __ERC20Permit_init("ARX NET Slice");
        __ERC20Votes_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        if (_tokenSale != address(0)) {
            tokenSale = IArxTokenSale(_tokenSale);
        }
        if (_uniswapRouter != address(0)) {
            uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        }
        if (_usdcToken != address(0)) {
            usdcToken = IERC20(_usdcToken);
        }
        if (_wethToken != address(0)) {
            wethToken = _wethToken;
        }
    }

    /// @inheritdoc IARX
    /// @dev Reverts if caller does not have MINTER_ROLE.
    function mint(
        address to,
        uint256 amount
    ) external override onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (totalMinted + amount > MAX_SUPPLY) revert MaxSupplyExceeded();
        totalMinted += amount;
        _mint(to, amount);
    }

    /// @notice ARX uses 6 decimals.
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    // --- OZ v5 Votes/Permit integration overrides ---

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, value);
    }

    function nonces(
        address owner
    )
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @notice Modifier to check if price contracts are initialized
    modifier priceContractsInitialized() {
        if (
            address(tokenSale) == address(0) ||
            address(uniswapRouter) == address(0) ||
            address(usdcToken) == address(0) ||
            wethToken == address(0)
        ) {
            revert PriceContractsNotInitialized();
        }
        _;
    }

    /// @notice Get exchange rate of token (ETH, USDT, USDC, etc.) to ARX
    /// @dev Converts token amount to USDC value using Uniswap, then calculates ARX amount using sale price
    /// @param token Token address (address(0) for ETH)
    /// @param tokenAmount Amount of tokens for exchange
    /// @return arxAmount Amount of ARX tokens that can be obtained
    function getTokenToArxExchangeRate(
        address token,
        uint256 tokenAmount
    ) external view priceContractsInitialized returns (uint256 arxAmount) {
        if (tokenAmount == 0) revert InvalidAmount();

        address actualToken = token == address(0) ? wethToken : token;
        uint256 usdcValue;

        if (actualToken == address(usdcToken)) {
            usdcValue = tokenAmount;
        } else {
            // Use Uniswap to get token price in USDC
            address[] memory path = new address[](2);
            path[0] = actualToken;
            path[1] = address(usdcToken);

            uint256[] memory amountsOut = uniswapRouter.getAmountsOut(
                tokenAmount,
                path
            );
            usdcValue = amountsOut[1];
        }

        // Get ARX price from sale contract - same formula as in ArxTokenSale.buyWithUSDC
        uint256 priceUSDC = tokenSale.priceUSDC();
        if (priceUSDC == 0) revert InvalidAmount();

        uint8 arxDecimals = tokenSale.arxDecimals();
        uint256 arxScale = 10 ** uint256(arxDecimals);

        // Calculate ARX amount using the same formula as ArxTokenSale:
        // arxAmount = (usdcValue * (10 ** arxDecimals)) / priceUSDC
        arxAmount = (usdcValue * arxScale) / priceUSDC;
    }

    /// @notice Calculates the price of ARX tokens in a specified token
    /// @dev Converts ARX amount to USDC value using sale price, then to target token using Uniswap
    /// @param token The token address to get ARX price in (address(0) for ETH)
    /// @param arxAmount The amount of ARX tokens to calculate price for
    /// @return price The equivalent value in the specified token
    function getArxPriceInToken(
        address token,
        uint256 arxAmount
    ) external view priceContractsInitialized returns (uint256 price) {
        if (arxAmount == 0) revert InvalidAmount();

        address actualToken = token == address(0) ? wethToken : token;

        // Get ARX price from sale contract - inverse formula of ArxTokenSale.buyWithUSDC
        uint256 priceUSDC = tokenSale.priceUSDC();
        if (priceUSDC == 0) revert InvalidAmount();

        uint8 arxDecimals = tokenSale.arxDecimals();
        uint256 arxScale = 10 ** uint256(arxDecimals);

        // Calculate USDC value using inverse formula:
        // usdcValue = (arxAmount * priceUSDC) / (10 ** arxDecimals)
        uint256 totalUsdValue = (arxAmount * priceUSDC) / arxScale;

        if (actualToken == address(usdcToken)) {
            return totalUsdValue;
        } else {
            // Use Uniswap to get USDC price in specified token
            address[] memory path = new address[](2);
            path[0] = address(usdcToken);
            path[1] = actualToken;

            uint256[] memory amountsOut = uniswapRouter.getAmountsOut(
                totalUsdValue,
                path
            );
            return amountsOut[1];
        }
    }

    /// @notice Updates the token sale contract address
    /// @param newTokenSale The new token sale contract address
    function setTokenSale(
        address newTokenSale
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTokenSale == address(0)) revert InvalidAddress();
        address previous = address(tokenSale);
        tokenSale = IArxTokenSale(newTokenSale);
        emit TokenSaleUpdated(previous, newTokenSale);
    }

    /// @notice Updates the Uniswap router address
    /// @param newUniswapRouter The new Uniswap router address
    function setUniswapRouter(
        address newUniswapRouter
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newUniswapRouter == address(0)) revert InvalidAddress();
        address previous = address(uniswapRouter);
        uniswapRouter = IUniswapV2Router02(newUniswapRouter);
        emit UniswapRouterUpdated(previous, newUniswapRouter);
    }

    /// @notice Updates the USDC token address
    /// @param newUsdcToken The new USDC token address
    function setUsdcToken(
        address newUsdcToken
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newUsdcToken == address(0)) revert InvalidAddress();
        address previous = address(usdcToken);
        usdcToken = IERC20(newUsdcToken);
        emit UsdcTokenUpdated(previous, newUsdcToken);
    }

    /// @notice Updates the WETH token address
    /// @param newWethToken The new WETH token address
    function setWethToken(
        address newWethToken
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newWethToken == address(0)) revert InvalidAddress();
        address previous = wethToken;
        wethToken = newWethToken;
        emit WethTokenUpdated(previous, newWethToken);
    }
}
