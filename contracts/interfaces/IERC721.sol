// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IERC721{
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
