// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

library LibERC165Data {
    function supportsInterface(ERC165Data storage self, bytes4 id) internal view returns (bool) {
        return id == 0x01ffc9a7 || self.INT_ifaces[id];
    }

    function add(ERC165Data storage self, bytes4 id) internal returns (ERC165Data storage) {
        self.INT_ifaces[id] = true;
        return self;
    }

    function remove(ERC165Data storage self, bytes4 id) internal returns (ERC165Data storage) {
        delete self.INT_ifaces[id];
        return self;
    }
}

struct ERC165Data {
    mapping(bytes4 => bool) INT_ifaces;
}

using LibERC165Data for ERC165Data global;
bytes32 constant ERC165_STORAGE_POSITION = keccak256("trilly.erc165");

function erc165() pure returns (ERC165Data storage s) {
    bytes32 position = ERC165_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

abstract contract TrillyERC165 {
    bytes32 private constant _ERC165_SLOT = keccak256("trilly.erc165");

    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool) {
        return erc165().supportsInterface(interfaceId);
    }
}
