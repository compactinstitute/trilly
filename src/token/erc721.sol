// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {ts} from "src/main.sol";
import {TrillyERC165} from "src/erc165.sol";

event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

interface IERC721TokenReceiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

library LibERC721Data {
    function init(ERC721Data storage) internal {
        ts.erc165().add(0x80ac58cd) // base
            .add(0x5b5e139f) // metadata
            .add(0x780e9d63); // enumerable
    }

    function balanceOf(ERC721Data storage self, address owner) internal view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for zero address");
        return self.INT_balances[owner];
    }

    function ownerOf(ERC721Data storage self, uint256 tokenId) internal view returns (address) {
        address owner = self.INT_owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function getApproved(ERC721Data storage self, uint256 tokenId) internal view returns (address) {
        require(self.INT_owners[tokenId] != address(0), "ERC721: approved query for nonexistent token");
        return self.INT_tokenApprovals[tokenId];
    }

    function isApprovedForAll(ERC721Data storage self, address owner, address operator) internal view returns (bool) {
        return self.INT_operatorApprovals[owner][operator];
    }

    function transferFrom(ERC721Data storage self, address caller, address from, address to, uint256 tokenId)
        internal
        returns (bool)
    {
        address owner = self.INT_owners[tokenId];
        require(owner != address(0), "ERC721: transfer of nonexistent token");
        require(owner == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to zero address");
        require(_isAuthorized(self, caller, owner, tokenId), "ERC721: caller not authorized");

        _transfer(self, from, to, tokenId);
        return true;
    }

    function safeTransferFrom(
        ERC721Data storage self,
        address caller,
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal returns (bool) {
        transferFrom(self, caller, from, to, tokenId);
        _checkOnERC721Received(caller, from, to, tokenId, data);
        return true;
    }

    function safeTransferFrom(ERC721Data storage self, address caller, address from, address to, uint256 tokenId)
        internal
        returns (bool)
    {
        return safeTransferFrom(self, caller, from, to, tokenId, "");
    }

    function approve(ERC721Data storage self, address caller, address approved, uint256 tokenId) internal {
        address owner = self.INT_owners[tokenId];
        require(owner != address(0), "ERC721: approve of nonexistent token");
        require(caller == owner || self.INT_operatorApprovals[owner][caller], "ERC721: caller not authorized");
        require(approved != owner, "ERC721: approve to current owner");

        self.INT_tokenApprovals[tokenId] = approved;
        emit Approval(owner, approved, tokenId);
    }

    function setApprovalForAll(ERC721Data storage self, address caller, address operator, bool approved) internal {
        require(operator != address(0), "ERC721: approve to zero address");
        self.INT_operatorApprovals[caller][operator] = approved;
        emit ApprovalForAll(caller, operator, approved);
    }

    function mint(ERC721Data storage self, address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to zero address");
        require(self.INT_owners[tokenId] == address(0), "ERC721: token already minted");

        self.INT_balances[to] += 1;
        self.INT_owners[tokenId] = to;

        _addTokenToAllTokens(self, tokenId);
        _addTokenToOwnerTokens(self, to, tokenId);

        emit Transfer(address(0), to, tokenId);
    }

    function burn(ERC721Data storage self, uint256 tokenId) internal {
        address owner = self.INT_owners[tokenId];
        require(owner != address(0), "ERC721: burn of nonexistent token");

        _removeTokenFromOwnerTokens(self, owner, tokenId);
        _removeTokenFromAllTokens(self, tokenId);

        delete self.INT_tokenApprovals[tokenId];
        self.INT_balances[owner] -= 1;
        delete self.INT_owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    function tokenURI(ERC721Data storage self, uint256 tokenId) internal view returns (string memory) {
        require(self.INT_owners[tokenId] != address(0), "ERC721Metadata: URI query for nonexistent token");

        string memory uri = self.INT_tokenURIs[tokenId];
        if (bytes(uri).length > 0) return uri;

        string memory base = self.INT_baseURI;
        if (bytes(base).length > 0) return string(abi.encodePacked(base, _toString(tokenId)));

        return "";
    }

    function setBaseURI(ERC721Data storage self, string memory baseURI) internal {
        self.INT_baseURI = baseURI;
    }

    function setTokenURI(ERC721Data storage self, uint256 tokenId, string memory uri) internal {
        require(self.INT_owners[tokenId] != address(0), "ERC721Metadata: URI set of nonexistent token");
        self.INT_tokenURIs[tokenId] = uri;
    }

    function totalSupply(ERC721Data storage self) internal view returns (uint256) {
        return self.INT_allTokens.length;
    }

    function tokenByIndex(ERC721Data storage self, uint256 index) internal view returns (uint256) {
        require(index < self.INT_allTokens.length, "ERC721Enumerable: index out of bounds");
        return self.INT_allTokens[index];
    }

    function tokenOfOwnerByIndex(ERC721Data storage self, address owner, uint256 index)
        internal
        view
        returns (uint256)
    {
        require(index < self.INT_balances[owner], "ERC721Enumerable: owner index out of bounds");
        return self.INT_ownedTokens[owner][index];
    }

    function _isAuthorized(ERC721Data storage self, address caller, address owner, uint256 tokenId)
        private
        view
        returns (bool)
    {
        return
            caller == owner || self.INT_tokenApprovals[tokenId] == caller || self.INT_operatorApprovals[owner][caller];
    }

    function _transfer(ERC721Data storage self, address from, address to, uint256 tokenId) private {
        _removeTokenFromOwnerTokens(self, from, tokenId);
        _addTokenToOwnerTokens(self, to, tokenId);

        delete self.INT_tokenApprovals[tokenId];
        self.INT_balances[from] -= 1;
        self.INT_balances[to] += 1;
        self.INT_owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(address caller, address from, address to, uint256 tokenId, bytes memory data)
        private
    {
        if (to.code.length > 0) {
            try IERC721TokenReceiver(to).onERC721Received(caller, from, tokenId, data) returns (bytes4 retval) {
                require(
                    retval == IERC721TokenReceiver.onERC721Received.selector, "ERC721: transfer to non-ERC721Receiver"
                );
            } catch (bytes memory) {
                revert("ERC721: transfer to non-ERC721Receiver");
            }
        }
    }

    function _addTokenToAllTokens(ERC721Data storage self, uint256 tokenId) private {
        self.INT_allTokensIndex[tokenId] = self.INT_allTokens.length;
        self.INT_allTokens.push(tokenId);
    }

    function _addTokenToOwnerTokens(ERC721Data storage self, address to, uint256 tokenId) private {
        self.INT_ownedTokensIndex[tokenId] = self.INT_ownedTokens[to].length;
        self.INT_ownedTokens[to].push(tokenId);
    }

    function _removeTokenFromAllTokens(ERC721Data storage self, uint256 tokenId) private {
        uint256 lastIndex = self.INT_allTokens.length - 1;
        uint256 tokenIndex = self.INT_allTokensIndex[tokenId];

        if (tokenIndex != lastIndex) {
            uint256 lastTokenId = self.INT_allTokens[lastIndex];
            self.INT_allTokens[tokenIndex] = lastTokenId;
            self.INT_allTokensIndex[lastTokenId] = tokenIndex;
        }

        self.INT_allTokens.pop();
        delete self.INT_allTokensIndex[tokenId];
    }

    function _removeTokenFromOwnerTokens(ERC721Data storage self, address from, uint256 tokenId) private {
        uint256 lastIndex = self.INT_ownedTokens[from].length - 1;
        uint256 tokenIndex = self.INT_ownedTokensIndex[tokenId];

        if (tokenIndex != lastIndex) {
            uint256 lastTokenId = self.INT_ownedTokens[from][lastIndex];
            self.INT_ownedTokens[from][tokenIndex] = lastTokenId;
            self.INT_ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        self.INT_ownedTokens[from].pop();
        delete self.INT_ownedTokensIndex[tokenId];
    }

    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            // casting to uint8 is fine since our buffer is small
            // forge-lint: disable-next-line(unsafe-typecast)
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

struct ERC721Data {
    string name;
    string symbol;
    string INT_baseURI;
    mapping(uint256 => address) INT_owners;
    mapping(address => uint256) INT_balances;
    mapping(uint256 => address) INT_tokenApprovals;
    mapping(address => mapping(address => bool)) INT_operatorApprovals;
    mapping(uint256 => string) INT_tokenURIs;
    uint256[] INT_allTokens;
    mapping(uint256 => uint256) INT_allTokensIndex;
    mapping(address => uint256[]) INT_ownedTokens;
    mapping(uint256 => uint256) INT_ownedTokensIndex;
}

using LibERC721Data for ERC721Data global;

abstract contract TrillyERC721 is TrillyERC165 {
    function name() external view virtual returns (string memory) {
        return ts.erc721().name;
    }

    function symbol() external view virtual returns (string memory) {
        return ts.erc721().symbol;
    }

    function balanceOf(address owner) external view virtual returns (uint256) {
        return ts.erc721().balanceOf(owner);
    }

    function ownerOf(uint256 tokenId) external view virtual returns (address) {
        return ts.erc721().ownerOf(tokenId);
    }

    function getApproved(uint256 tokenId) external view virtual returns (address) {
        return ts.erc721().getApproved(tokenId);
    }

    function isApprovedForAll(address owner, address operator) external view virtual returns (bool) {
        return ts.erc721().isApprovedForAll(owner, operator);
    }

    function transferFrom(address from, address to, uint256 tokenId) external virtual {
        ts.erc721().transferFrom(msg.sender, from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external virtual {
        ts.erc721().safeTransferFrom(msg.sender, from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external virtual {
        ts.erc721().safeTransferFrom(msg.sender, from, to, tokenId, data);
    }

    function approve(address approved, uint256 tokenId) external virtual {
        ts.erc721().approve(msg.sender, approved, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external virtual {
        ts.erc721().setApprovalForAll(msg.sender, operator, approved);
    }

    function tokenURI(uint256 tokenId) external view virtual returns (string memory) {
        return ts.erc721().tokenURI(tokenId);
    }

    function totalSupply() external view virtual returns (uint256) {
        return ts.erc721().totalSupply();
    }

    function tokenByIndex(uint256 index) external view virtual returns (uint256) {
        return ts.erc721().tokenByIndex(index);
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external view virtual returns (uint256) {
        return ts.erc721().tokenOfOwnerByIndex(owner, index);
    }
}
