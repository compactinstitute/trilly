// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {ts} from "src/main.sol";
import {TrillyERC721, ERC721Data, LibERC721Data, IERC721TokenReceiver} from "src/token/erc721.sol";

event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

contract ERC721Wrapper is TrillyERC721 {
    constructor(string memory name_, string memory symbol_) {
        ERC721Data storage e = ts.erc721();
        e.name = name_;
        e.symbol = symbol_;
        e.init();
    }

    function mint(address to, uint256 tokenId) external {
        ts.erc721().mint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        ts.erc721().burn(tokenId);
    }

    function setBaseURI(string memory baseURI) external {
        ts.erc721().setBaseURI(baseURI);
    }

    function setTokenURI(uint256 tokenId, string memory uri) external {
        ts.erc721().setTokenURI(tokenId, uri);
    }
}

contract ERC721Receiver is IERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract ERC721Test is Test {
    ERC721Wrapper token;
    address alice = address(0x420001);
    address bob = address(0x420002);
    address charlie = address(0x420003);

    function setUp() public {
        token = new ERC721Wrapper("TestNFT", "NFT");
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(bob, 3);
    }

    function test_metadata() public view {
        assertEq(token.name(), "TestNFT");
        assertEq(token.symbol(), "NFT");
    }

    function test_balanceOf() public view {
        assertEq(token.balanceOf(alice), 2);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.balanceOf(charlie), 0);
    }

    function test_balanceOf_zeroAddress() public {
        vm.expectRevert("ERC721: balance query for zero address");
        token.balanceOf(address(0));
    }

    function test_ownerOf() public {
        assertEq(token.ownerOf(1), alice);
        assertEq(token.ownerOf(2), alice);
        assertEq(token.ownerOf(3), bob);
    }

    function test_ownerOf_nonexistent() public {
        vm.expectRevert("ERC721: owner query for nonexistent token");
        token.ownerOf(999);
    }

    function test_transferFrom() public {
        vm.prank(alice);
        token.transferFrom(alice, bob, 1);

        assertEq(token.ownerOf(1), bob);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), 2);
    }

    function test_transferFrom_emitsTransferEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, 1);
        token.transferFrom(alice, bob, 1);
    }

    function test_transferFrom_notOwner() public {
        vm.prank(bob);
        vm.expectRevert("ERC721: caller not authorized");
        token.transferFrom(alice, charlie, 1);
    }

    function test_transferFrom_approvedCaller() public {
        vm.prank(alice);
        token.approve(bob, 2);

        vm.prank(bob);
        token.transferFrom(alice, charlie, 2);

        assertEq(token.ownerOf(2), charlie);
    }

    function test_transferFrom_operatorCaller() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.transferFrom(alice, charlie, 1);

        assertEq(token.ownerOf(1), charlie);
    }

    function test_transferFrom_wrongFrom() public {
        vm.prank(alice);
        vm.expectRevert("ERC721: transfer from incorrect owner");
        token.transferFrom(bob, charlie, 1);
    }

    function test_transferFrom_nonexistent() public {
        vm.prank(alice);
        vm.expectRevert("ERC721: transfer of nonexistent token");
        token.transferFrom(alice, bob, 999);
    }

    function test_transferFrom_zeroAddress() public {
        vm.prank(alice);
        vm.expectRevert("ERC721: transfer to zero address");
        token.transferFrom(alice, address(0), 1);
    }

    function test_safeTransferFrom_toEOA() public {
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 1);

        assertEq(token.ownerOf(1), bob);
    }

    function test_safeTransferFrom_toContract() public {
        ERC721Receiver receiver = new ERC721Receiver();
        vm.prank(alice);
        token.safeTransferFrom(alice, address(receiver), 1);

        assertEq(token.ownerOf(1), address(receiver));
    }

    function test_safeTransferFrom_toContractWithoutReceiver() public {
        vm.prank(alice);
        vm.expectRevert("ERC721: transfer to non-ERC721Receiver");
        token.safeTransferFrom(alice, address(token), 1);
    }

    function test_safeTransferFrom_withData() public {
        ERC721Receiver receiver = new ERC721Receiver();
        vm.prank(alice);
        token.safeTransferFrom(alice, address(receiver), 2, "hello");

        assertEq(token.ownerOf(2), address(receiver));
    }

    function test_approve() public {
        vm.prank(alice);
        token.approve(bob, 1);
        assertEq(token.getApproved(1), bob);
    }

    function test_approve_emitsApprovalEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, 1);
        token.approve(bob, 1);
    }

    function test_approve_nonexistent() public {
        vm.expectRevert("ERC721: approve of nonexistent token");
        token.approve(bob, 999);
    }

    function test_approve_notOwner() public {
        vm.prank(bob);
        vm.expectRevert("ERC721: caller not authorized");
        token.approve(charlie, 1);
    }

    function test_approve_clearsOnTransfer() public {
        vm.prank(alice);
        token.approve(bob, 1);
        assertEq(token.getApproved(1), bob);

        vm.prank(alice);
        token.transferFrom(alice, charlie, 1);

        assertEq(token.getApproved(1), address(0));
    }

    function test_getApproved() public {
        vm.prank(alice);
        token.approve(bob, 1);
        assertEq(token.getApproved(1), bob);
    }

    function test_getApproved_nonexistent() public {
        vm.expectRevert("ERC721: approved query for nonexistent token");
        token.getApproved(999);
    }

    function test_setApprovalForAll() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);
        assertTrue(token.isApprovedForAll(alice, bob));
    }

    function test_setApprovalForAll_emitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, true);
        token.setApprovalForAll(bob, true);
    }

    function test_setApprovalForAll_revokes() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);
        assertTrue(token.isApprovedForAll(alice, bob));

        vm.prank(alice);
        token.setApprovalForAll(bob, false);
        assertFalse(token.isApprovedForAll(alice, bob));
    }

    function test_setApprovalForAll_emitsRevokeEvent() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, false);
        token.setApprovalForAll(bob, false);
    }

    function test_isApprovedForAll_default() public view {
        assertFalse(token.isApprovedForAll(alice, bob));
    }

    function test_totalSupply() public view {
        assertEq(token.totalSupply(), 3);
    }

    function test_tokenByIndex() public view {
        assertEq(token.tokenByIndex(0), 1);
        assertEq(token.tokenByIndex(1), 2);
        assertEq(token.tokenByIndex(2), 3);
    }

    function test_tokenByIndex_outOfBounds() public {
        vm.expectRevert("ERC721Enumerable: index out of bounds");
        token.tokenByIndex(3);
    }

    function test_tokenOfOwnerByIndex() public view {
        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 1), 2);
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 3);
    }

    function test_tokenOfOwnerByIndex_outOfBounds() public {
        vm.expectRevert("ERC721Enumerable: owner index out of bounds");
        token.tokenOfOwnerByIndex(alice, 2);
    }

    function test_tokenURI_default() public view {
        assertEq(token.tokenURI(1), "");
    }

    function test_tokenURI_withBaseURI() public {
        token.setBaseURI("https://example.com/nft/");
        assertEq(token.tokenURI(1), "https://example.com/nft/1");
    }

    function test_tokenURI_withTokenURI() public {
        token.setTokenURI(1, "https://example.com/nft/foo.json");
        assertEq(token.tokenURI(1), "https://example.com/nft/foo.json");
    }

    function test_tokenURI_nonexistent() public {
        vm.expectRevert("ERC721Metadata: URI query for nonexistent token");
        token.tokenURI(999);
    }

    function test_burn() public {
        token.burn(1);

        assertEq(token.balanceOf(alice), 1);
        assertEq(token.totalSupply(), 2);
        vm.expectRevert("ERC721: owner query for nonexistent token");
        token.ownerOf(1);
    }

    function test_burn_clearsApproval() public {
        vm.prank(alice);
        token.approve(bob, 1);
        token.burn(1);

        vm.expectRevert("ERC721: approved query for nonexistent token");
        token.getApproved(1);
    }

    function test_supportsInterface_erc165() public view {
        assertTrue(token.supportsInterface(0x01ffc9a7));
    }

    function test_supportsInterface_erc721() public view {
        assertTrue(token.supportsInterface(0x80ac58cd));
    }

    function test_supportsInterface_erc721Metadata() public view {
        assertTrue(token.supportsInterface(0x5b5e139f));
    }

    function test_supportsInterface_erc721Enumerable() public view {
        assertTrue(token.supportsInterface(0x780e9d63));
    }

    function test_supportsInterface_random() public view {
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function test_supportsInterface_unregistered() public view {
        assertFalse(token.supportsInterface(0xd9b67a26));
    }
}
