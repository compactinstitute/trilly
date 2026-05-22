// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {ts} from "src/main.sol";
import {TrillyERC165} from "src/erc165.sol";

event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
event TransferBatch(
    address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
);
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
event URI(string value, uint256 indexed id);

interface IERC1155TokenReceiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        returns (bytes4);
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

library LibERC1155Data {
    function init(ERC1155Data storage) internal {
        ts.erc165().add(0xd9b67a26);
    }

    function balanceOf(ERC1155Data storage self, address owner, uint256 id) internal view returns (uint256) {
        require(owner != address(0), "ERC1155: balance query for zero address");
        return self.INT_balances[id][owner];
    }

    function balanceOfBatch(ERC1155Data storage self, address[] memory owners, uint256[] memory ids)
        internal
        view
        returns (uint256[] memory)
    {
        require(owners.length == ids.length, "ERC1155: owners and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](owners.length);
        for (uint256 i = 0; i < owners.length; ++i) {
            batchBalances[i] = self.INT_balances[ids[i]][owners[i]];
        }
        return batchBalances;
    }

    function safeTransferFrom(
        ERC1155Data storage self,
        address caller,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: transfer to zero address");
        require(caller == from || self.INT_operatorApprovals[from][caller], "ERC1155: caller not authorized");

        uint256 fromBalance = self.INT_balances[id][from];
        require(fromBalance >= value, "ERC1155: insufficient balance");

        self.INT_balances[id][from] = fromBalance - value;
        self.INT_balances[id][to] += value;

        emit TransferSingle(caller, from, to, id, value);

        _checkOnERC1155Received(caller, from, to, id, value, data);
    }

    function safeBatchTransferFrom(
        ERC1155Data storage self,
        address caller,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: transfer to zero address");
        require(ids.length == values.length, "ERC1155: ids and values length mismatch");
        require(caller == from || self.INT_operatorApprovals[from][caller], "ERC1155: caller not authorized");

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 value = values[i];
            uint256 fromBalance = self.INT_balances[id][from];
            require(fromBalance >= value, "ERC1155: insufficient balance");

            self.INT_balances[id][from] = fromBalance - value;
            self.INT_balances[id][to] += value;
        }

        emit TransferBatch(caller, from, to, ids, values);

        _checkOnERC1155BatchReceived(caller, from, to, ids, values, data);
    }

    function setApprovalForAll(ERC1155Data storage self, address caller, address operator, bool approved) internal {
        self.INT_operatorApprovals[caller][operator] = approved;
        emit ApprovalForAll(caller, operator, approved);
    }

    function isApprovedForAll(ERC1155Data storage self, address owner, address operator) internal view returns (bool) {
        return self.INT_operatorApprovals[owner][operator];
    }

    function mint(ERC1155Data storage self, address to, uint256 id, uint256 value, bytes memory data) internal {
        require(to != address(0), "ERC1155: mint to zero address");

        self.INT_balances[id][to] += value;

        emit TransferSingle(msg.sender, address(0), to, id, value);

        _checkOnERC1155Received(msg.sender, address(0), to, id, value, data);
    }

    function mintBatch(
        ERC1155Data storage self,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: mint to zero address");
        require(ids.length == values.length, "ERC1155: ids and values length mismatch");

        for (uint256 i = 0; i < ids.length; ++i) {
            self.INT_balances[ids[i]][to] += values[i];
        }

        emit TransferBatch(msg.sender, address(0), to, ids, values);

        _checkOnERC1155BatchReceived(msg.sender, address(0), to, ids, values, data);
    }

    function burn(ERC1155Data storage self, address from, uint256 id, uint256 value) internal {
        uint256 fromBalance = self.INT_balances[id][from];
        require(fromBalance >= value, "ERC1155: burn amount exceeds balance");

        self.INT_balances[id][from] = fromBalance - value;

        emit TransferSingle(msg.sender, from, address(0), id, value);
    }

    function burnBatch(ERC1155Data storage self, address from, uint256[] memory ids, uint256[] memory values) internal {
        require(ids.length == values.length, "ERC1155: ids and values length mismatch");

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 value = values[i];
            uint256 fromBalance = self.INT_balances[id][from];
            require(fromBalance >= value, "ERC1155: burn amount exceeds balance");

            self.INT_balances[id][from] = fromBalance - value;
        }

        emit TransferBatch(msg.sender, from, address(0), ids, values);
    }

    function uri(ERC1155Data storage self, uint256 id) internal view returns (string memory) {
        string memory base = self.INT_uri;
        bytes memory baseBytes = bytes(base);

        uint256 idPos = _indexOf(baseBytes, "{id}");
        if (idPos == type(uint256).max) return base;

        string memory idHex = _toHexString(id, 64);
        bytes memory idHexBytes = bytes(idHex);

        bytes memory result = new bytes(baseBytes.length - 4 + idHexBytes.length);

        uint256 i = 0;
        for (; i < idPos; ++i) {
            result[i] = baseBytes[i];
        }
        for (uint256 j = 0; j < idHexBytes.length; ++j) {
            result[i + j] = idHexBytes[j];
        }
        for (uint256 j = idPos + 4; j < baseBytes.length; ++j) {
            result[i + idHexBytes.length + j - idPos - 4] = baseBytes[j];
        }

        return string(result);
    }

    function setURI(ERC1155Data storage self, string memory newURI) internal {
        self.INT_uri = newURI;
        emit URI(newURI, type(uint256).max);
    }

    function _checkOnERC1155Received(
        address caller,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155TokenReceiver(to).onERC1155Received(caller, from, id, value, data) returns (bytes4 retval) {
                require(
                    retval == IERC1155TokenReceiver.onERC1155Received.selector,
                    "ERC1155: transfer to non-ERC1155Receiver"
                );
            } catch (bytes memory) {
                revert("ERC1155: transfer to non-ERC1155Receiver");
            }
        }
    }

    function _checkOnERC1155BatchReceived(
        address caller,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155TokenReceiver(to).onERC1155BatchReceived(caller, from, ids, values, data) returns (
                bytes4 retval
            ) {
                require(
                    retval == IERC1155TokenReceiver.onERC1155BatchReceived.selector,
                    "ERC1155: transfer to non-ERC1155Receiver"
                );
            } catch (bytes memory) {
                revert("ERC1155: transfer to non-ERC1155Receiver");
            }
        }
    }

    function _indexOf(bytes memory haystack, string memory needle) private pure returns (uint256) {
        bytes memory needleBytes = bytes(needle);
        if (needleBytes.length == 0) return 0;
        if (needleBytes.length > haystack.length) return type(uint256).max;

        for (uint256 i = 0; i <= haystack.length - needleBytes.length; ++i) {
            bool found = true;
            for (uint256 j = 0; j < needleBytes.length; ++j) {
                if (haystack[i + j] != needleBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return i;
        }
        return type(uint256).max;
    }

    function _toHexString(uint256 value, uint256 length) private pure returns (string memory) {
        bytes memory buffer = new bytes(length);
        for (uint256 i = 1; i <= length; ++i) {
            buffer[length - i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }

    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
}

struct ERC1155Data {
    string INT_uri;
    mapping(uint256 => mapping(address => uint256)) INT_balances;
    mapping(address => mapping(address => bool)) INT_operatorApprovals;
}

using LibERC1155Data for ERC1155Data global;

abstract contract TrillyERC1155 is TrillyERC165 {
    function balanceOf(address owner, uint256 id) external view virtual returns (uint256) {
        return ts.erc1155().balanceOf(owner, id);
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        external
        view
        virtual
        returns (uint256[] memory)
    {
        return ts.erc1155().balanceOfBatch(owners, ids);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data)
        external
        virtual
    {
        ts.erc1155().safeTransferFrom(msg.sender, from, to, id, value, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external virtual {
        ts.erc1155().safeBatchTransferFrom(msg.sender, from, to, ids, values, data);
    }

    function setApprovalForAll(address operator, bool approved) external virtual {
        ts.erc1155().setApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) external view virtual returns (bool) {
        return ts.erc1155().isApprovedForAll(owner, operator);
    }

    function uri(uint256 id) external view virtual returns (string memory) {
        return ts.erc1155().uri(id);
    }
}
