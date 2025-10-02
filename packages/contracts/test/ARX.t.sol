// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ARX } from "../src/ARX.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ARXTest is Test {
    ARX token;
    address admin = address(0xA11CE);
    address minter = address(0xBEEF);
    address user = address(0xCAFE);

    function setUp() public {
        ARX impl = new ARX();
        bytes memory data = abi.encodeWithSelector(ARX.initialize.selector, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), data);
        token = ARX(address(proxy));
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
    }

    function testMintByMinter() public {
        vm.prank(minter);
        token.mint(user, 1 ether);
        assertEq(token.balanceOf(user), 1 ether);
    }

    function test_RevertWhen_NonMinterMints() public {
        vm.expectRevert();
        token.mint(user, 1 ether);
    }
}
