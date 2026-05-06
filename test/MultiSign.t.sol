// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
// import {Counter} from "../src/Counter.sol";
import "../src/MultiSign.sol";
import "forge-std/console.sol";

contract MultiSignTest is Test {
    // 多个用户。
    address userCreator = address(0x3000);
    address user1 = address(0x3001);
    address user2 = address(0x3002);
    address user3 = address(0x3003);
    address user4 = address(0x3004);
    address user5 = address(0x3005);
    address userTo = address(0x3099);

    MultiSignContract multiSign;
    address multiSignAddr;
    uint txIdA;

    function setUp() public {
        address[] memory ownerList = new address[](2);
        ownerList[0] = user1;
        ownerList[1] = user2;
        vm.prank(userCreator);
        multiSign = new MultiSignContract(ownerList, 2);
        multiSignAddr = address(multiSign);

        // 给钱包转账。
        vm.deal(user1, 1000);
        vm.prank(user1);
        (bool ok, ) = payable(multiSignAddr).call{value: 500}("");
        require(ok, "init error");

        // 交易。
        vm.prank(userCreator);
        txIdA = multiSign.createTx("buy orange", userTo, 100);
    }

    // 测试创建、查询。
    function test_create() public {
        // address[2] memory ownerList = [user1, user2];// 加了size，传不进去。

        vm.startPrank(userCreator);
        // 有重复的user。
        address[] memory ownerListRepeat = new address[](2);
        ownerListRepeat[0] = user1;
        // ownerListRepeat[1] = userCreator; // [FAIL: >>>  owner repeat]
        ownerListRepeat[1] = user1; // [FAIL: >>>  owner repeat]
        // MultiSignContract contract2 = new MultiSignContract(ownerListRepeat, 2);
        vm.stopPrank();

        // 创建。
        vm.prank(userCreator);
        uint txIdB = multiSign.createTx("buy fish", userTo, 100);
        vm.prank(userCreator);
        uint txIdC = multiSign.createTx("buy book", userTo, 100);
        console.log(unicode"创建 A = ", txIdA);
        console.log(unicode"创建 B = ", txIdB);
        console.log(unicode"创建 C = ", txIdC);
        require(txIdC == txIdB + 1, "txId invalid");

        // 查询。
        vm.prank(userCreator);
        (
            uint txId_,
            address creator,
            address to,
            uint goal,
            string memory title,
            uint ownerCount,
            uint needConfirm,
            TxState state
        ) = multiSign.queryTx(txIdC);
        console.log(unicode"查询 ： ");
        console.log("   txId_ = ", txId_);
        console.log("   creator = ", creator);
        console.log("   to = ", to);
        console.log("   goal = ", goal);
        console.log("   title = ", title);
        console.log("   ownerCount = ", ownerCount);
        console.log("   needConfirm = ", needConfirm);
        console.log("   state = ", uint(state));
        require(creator == userCreator, "creator invalid");

        // 部署owner。不能查询。
        // vm.prank(user5); // [Revert] user not owner
        // multiSign.queryTx(txIdC);
    }

    // 测试owner增加、删除。
    function test_owner() public {
        address[] memory list1 = multiSign.queryOwnerList();
        console.log(unicode"修改owner前，owner数量 = ", list1.length);
        for (uint k = 0; k < list1.length; k++) {
            console.log("  owner = ", list1[k]);
        }

        vm.prank(userCreator); // 可以。 是owner
        (uint ownerCount1, string memory desc) = multiSign.ownerAddOne(user1);
        console.log("put user1 = ", desc);
        console.log(unicode"增加 user1 ，ownerCount1 = ", ownerCount1);
        require(ownerCount1 == 3, "ownerCount1 not match");

        vm.prank(user2); // 可以。 是owner
        (uint ownerCount2, string memory desc2) = multiSign.ownerAddOne(user5);
        console.log("put user5 = ", desc2);
        console.log(unicode"增加 user5 ，ownerCount2 = ", ownerCount2);
        require(ownerCount2 == 4, "ownerCount2 not match");

        vm.prank(user5);
        (uint ownerCount3) = multiSign.ownerRemoveOne(user2);
        console.log(unicode"移除 user2 ，ownerCount3 = ", ownerCount3);
        require(ownerCount3 == 3, "ownerCount3 not match");

        address[] memory list2 = multiSign.queryOwnerList();
        console.log(unicode"修改owner后，owner数量 = ", list2.length);
        for (uint k = 0; k < list2.length; k++) {
            console.log("  owner = ", list2[k]);
        }
    }
    // 确认与取消。
    function test_confirm() public {
        // 确认1个。数量+1
        vm.prank(user1);
        uint count1 = multiSign.confirmOnce(txIdA);
        console.log(unicode"user1 确认后。 确认数量=", count1);
        require(count1 == 1, "confirm count1 error");

        // 又确认1个。数量+1
        vm.prank(userCreator);
        uint count2 = multiSign.confirmOnce(txIdA);
        console.log(unicode"userCreator 确认后。 确认数量=", count2);
        require(count2 == 2, "confirm count2 error");

        // 重复确认。 忽略。
        vm.prank(user1);
        uint count3 = multiSign.confirmOnce(txIdA);
        console.log(unicode"user1 确认后。 确认数量=", count3);
        require(count3 == 2, "confirm count3 error");

        // 不是owner。异常。
        // vm.prank(user5); // [Revert] user not owner
        // uint count4 = multiSign.confirmOnce(txIdA);

        // 取消1个。数量-1
        vm.prank(userCreator);
        uint count5 = multiSign.confirmRevoke(txIdA);
        console.log(unicode"userCreator 取消后。 确认数量=", count5);
        require(count5 == 1, "confirm count5 error");

        // 执行。数量不够，失败了。
        // vm.prank(user4); // [Revert] user not owner
        vm.prank(user1);
        (bool ok1, string memory desc1) = multiSign.executeTx(txIdA);
        console.log(unicode"数量不够，执行1次 =", desc1);
        assert(!ok1);

        // 再确认一个。
        vm.prank(user2);
        uint count6 = multiSign.confirmOnce(txIdA);
        console.log(unicode"user2 确认后。 确认数量=", count6);
        require(count6 == 2, "confirm count6 error");

        // 执行前的余额。
        uint balanceWalletBefore = multiSignAddr.balance;

        // 数量够了，执行成功。
        vm.prank(user1);
        (bool ok2, string memory desc2) = multiSign.executeTx(txIdA);
        console.log(unicode"数量够了，执行1次 =", desc2);
        assert(ok2);

        // 执行后的余额。
        uint balanceWalletAfter = multiSignAddr.balance;
        uint balanceTo = userTo.balance;
        console.log(unicode"执行前的余额 = ", balanceWalletBefore);
        console.log(unicode"执行后的余额 = ", balanceWalletAfter);
        console.log(unicode"To的余额 = ", balanceTo);
        require(
            balanceWalletBefore == balanceWalletAfter + 100,
            "wallet transfer error"
        );
        require(balanceTo == 100, "balanceTo error");

        // 重复执行。异常。状态变了。 [Revert] state not match
        // vm.prank(user1);
        // (bool ok3, string memory desc3) = multiSign.executeTx(txIdA);
    }
}
