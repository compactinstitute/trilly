// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {ts} from "src/main.sol";
import {TrillyERC1155, ERC1155Data, LibERC1155Data, IERC1155TokenReceiver} from "src/token/erc1155.sol";

event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
event TransferBatch(
    address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
);
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

contract ERC1155Wrapper is TrillyERC1155 {
    constructor() {
        ERC1155Data storage e = ts.erc1155();
        e.setURI("https://example.com/token/{id}.json");
        e.init();
    }

    function mint(address to, uint256 id, uint256 value, bytes memory data) external {
        ts.erc1155().mint(to, id, value, data);
    }

    function burn(address from, uint256 id, uint256 value) external {
        ts.erc1155().burn(from, id, value);
    }

    function setURI(string memory newURI) external {
        ts.erc1155().setURI(newURI);
    }
}

contract ERC1155Receiver is IERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }
}

contract ERC1155Test is Test {
    ERC1155Wrapper token;
    address alice = address(0x420001);
    address bob = address(0x420002);
    address charlie = address(0x420003);

    function setUp() public {
        token = new ERC1155Wrapper();
        token.mint(alice, 1, 1000, "");
        token.mint(alice, 2, 2000, "");
        token.mint(bob, 1, 500, "");
    }

    function test_balanceOf() public view {
        assertEq(token.balanceOf(alice, 1), 1000);
        assertEq(token.balanceOf(alice, 2), 2000);
        assertEq(token.balanceOf(bob, 1), 500);
        assertEq(token.balanceOf(bob, 2), 0);
        assertEq(token.balanceOf(charlie, 1), 0);
    }

    function test_balanceOf_zeroAddress() public {
        vm.expectRevert("ERC1155: balance query for zero address");
        token.balanceOf(address(0), 1);
    }

    function test_balanceOfBatch() public view {
        address[] memory owners = new address[](4);
        owners[0] = alice;
        owners[1] = alice;
        owners[2] = bob;
        owners[3] = charlie;

        uint256[] memory ids = new uint256[](4);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 1;
        ids[3] = 1;

        uint256[] memory balances = token.balanceOfBatch(owners, ids);

        assertEq(balances.length, 4);
        assertEq(balances[0], 1000);
        assertEq(balances[1], 2000);
        assertEq(balances[2], 500);
        assertEq(balances[3], 0);
    }

    function test_balanceOfBatch_lengthMismatch() public {
        address[] memory owners = new address[](1);
        owners[0] = alice;
        uint256[] memory ids = new uint256[](2);

        vm.expectRevert("ERC1155: owners and ids length mismatch");
        token.balanceOfBatch(owners, ids);
    }

    function test_safeTransferFrom() public {
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 1, 300, "");

        assertEq(token.balanceOf(alice, 1), 700);
        assertEq(token.balanceOf(bob, 1), 800);
    }

    function test_safeTransferFrom_emitsTransferSingleEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit TransferSingle(alice, alice, bob, 1, 300);
        token.safeTransferFrom(alice, bob, 1, 300, "");
    }

    function test_safeTransferFrom_operator() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.safeTransferFrom(alice, charlie, 1, 200, "");

        assertEq(token.balanceOf(alice, 1), 800);
        assertEq(token.balanceOf(charlie, 1), 200);
    }

    function test_safeTransferFrom_notAuthorized() public {
        vm.prank(bob);
        vm.expectRevert("ERC1155: caller not authorized");
        token.safeTransferFrom(alice, charlie, 1, 100, "");
    }

    function test_safeTransferFrom_zeroAddress() public {
        vm.prank(alice);
        vm.expectRevert("ERC1155: transfer to zero address");
        token.safeTransferFrom(alice, address(0), 1, 100, "");
    }

    function test_safeTransferFrom_insufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert("ERC1155: insufficient balance");
        token.safeTransferFrom(alice, bob, 1, 2000, "");
    }

    function test_safeTransferFrom_toContract() public {
        ERC1155Receiver receiver = new ERC1155Receiver();
        vm.prank(alice);
        token.safeTransferFrom(alice, address(receiver), 1, 200, "");

        assertEq(token.balanceOf(address(receiver), 1), 200);
    }

    function test_safeTransferFrom_toContractWithoutReceiver() public {
        vm.prank(alice);
        vm.expectRevert("ERC1155: transfer to non-ERC1155Receiver");
        token.safeTransferFrom(alice, address(token), 1, 200, "");
    }

    function test_safeBatchTransferFrom() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 300;

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(token.balanceOf(alice, 1), 900);
        assertEq(token.balanceOf(bob, 1), 600);
        assertEq(token.balanceOf(alice, 2), 1700);
        assertEq(token.balanceOf(bob, 2), 300);
    }

    function test_safeBatchTransferFrom_emitsTransferBatchEvent() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 300;

        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit TransferBatch(alice, alice, bob, ids, amounts);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    function test_safeBatchTransferFrom_operator() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 300;

        vm.prank(bob);
        token.safeBatchTransferFrom(alice, charlie, ids, amounts, "");

        assertEq(token.balanceOf(charlie, 1), 100);
        assertEq(token.balanceOf(charlie, 2), 300);
    }

    function test_safeBatchTransferFrom_notAuthorized() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        vm.prank(bob);
        vm.expectRevert("ERC1155: caller not authorized");
        token.safeBatchTransferFrom(alice, charlie, ids, amounts, "");
    }

    function test_safeBatchTransferFrom_zeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        vm.prank(alice);
        vm.expectRevert("ERC1155: transfer to zero address");
        token.safeBatchTransferFrom(alice, address(0), ids, amounts, "");
    }

    function test_safeBatchTransferFrom_lengthMismatch() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        uint256[] memory amounts = new uint256[](2);

        vm.prank(alice);
        vm.expectRevert("ERC1155: ids and values length mismatch");
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    function test_safeBatchTransferFrom_insufficientBalance() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2000;

        vm.prank(alice);
        vm.expectRevert("ERC1155: insufficient balance");
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
    }

    function test_safeBatchTransferFrom_toContract() public {
        ERC1155Receiver receiver = new ERC1155Receiver();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 300;

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, address(receiver), ids, amounts, "");

        assertEq(token.balanceOf(address(receiver), 1), 100);
        assertEq(token.balanceOf(address(receiver), 2), 300);
    }

    function test_safeBatchTransferFrom_toContractWithoutReceiver() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        vm.prank(alice);
        vm.expectRevert("ERC1155: transfer to non-ERC1155Receiver");
        token.safeBatchTransferFrom(alice, address(token), ids, amounts, "");
    }

    function test_setApprovalForAll() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);
        assertTrue(token.isApprovedForAll(alice, bob));
    }

    function test_setApprovalForAll_emitsApprovalForAllEvent() public {
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

    function test_isApprovedForAll_default() public view {
        assertFalse(token.isApprovedForAll(alice, bob));
    }

    function test_uri() public view {
        assertEq(
            token.uri(1),
            "https://example.com/token/0000000000000000000000000000000000000000000000000000000000000001.json"
        );
    }

    function test_uri_withoutSubstitution() public {
        token.setURI("https://example.com/static.json");
        assertEq(token.uri(1), "https://example.com/static.json");
    }

    function test_burn() public {
        token.burn(alice, 1, 300);
        assertEq(token.balanceOf(alice, 1), 700);
    }

    function test_burn_exceedsBalance() public {
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        token.burn(alice, 1, 2000);
    }

    function test_supportsInterface_erc165() public view {
        assertTrue(token.supportsInterface(0x01ffc9a7));
    }

    function test_supportsInterface_erc1155() public view {
        assertTrue(token.supportsInterface(0xd9b67a26));
    }

    function test_supportsInterface_random() public view {
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function test_supportsInterface_unregistered() public view {
        assertFalse(token.supportsInterface(0x80ac58cd));
    }
}
