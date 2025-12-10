// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    ERC1967Proxy as OZERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Thin wrapper to make ERC1967Proxy available under local src for forge create
contract ERC1967Proxy is OZERC1967Proxy {
    constructor(address _logic, bytes memory _data) OZERC1967Proxy(_logic, _data) { }
}
