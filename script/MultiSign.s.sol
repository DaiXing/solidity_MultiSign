// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
// import {Counter} from "../src/Counter.sol";
import "../src/MultiSign.sol";

// 部署。
contract MultiSignScript is Script {
    MultiSignContract public multiSignContract;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address[] memory ownerList = new address[](0);
        multiSignContract = new MultiSignContract(ownerList, 2);

        vm.stopBroadcast();
    }
}
