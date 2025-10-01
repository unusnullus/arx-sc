// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ARX } from "../src/ARX.sol";

contract ARXTest is Test {
    ARX token;
    address admin = address(0xA11CE);
    address minter = address(0xBEEF);
    address user = address(0xCAFE);

    function setUp() public {
        token = new ARX(admin);
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
