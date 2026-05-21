// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {ERC20Data} from "src/token/erc20.sol";
import {ERC721Data} from "src/token/erc721.sol";
import {ERC1155Data} from "src/token/erc1155.sol";
import {ERC165Data} from "src/erc165.sol";

// ts, short for Trilly Storage
library ts {
    bytes32 internal constant ERC20_STORAGE_POSITION = keccak256("trilly.erc20");
    bytes32 internal constant ERC721_STORAGE_POSITION = keccak256("trilly.erc721");
    bytes32 internal constant ERC1155_STORAGE_POSITION = keccak256("trilly.erc1155");
    bytes32 internal constant ERC165_STORAGE_POSITION = keccak256("trilly.erc165");

    function erc20() internal pure returns (ERC20Data storage s) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function erc165() internal pure returns (ERC165Data storage s) {
        bytes32 position = ERC165_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function erc721() internal pure returns (ERC165Data storage s) {
        bytes32 position = ERC721_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function erc1155() internal pure returns (ERC165Data storage s) {
        bytes32 position = ERC1155_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
