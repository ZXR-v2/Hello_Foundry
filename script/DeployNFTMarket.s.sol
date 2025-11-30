// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../src/MyERC20.sol";
import "../src/MyERC721.sol";
import "../src/NFTMarket.sol";

contract DeployNFTMarket is Script {
    function run() external {
        ////////////////////////////////////////
        // 1. 启动广播
        ////////////////////////////////////////

        // 推荐两种用法二选一：

        // 方式一：用环境变量里的 PRIVATE_KEY
        // uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        // vm.startBroadcast(deployerKey);

        // 方式二：在命令行传 --private-key，
        // 这里就用无参 startBroadcast()
        vm.startBroadcast();

        ////////////////////////////////////////
        // 2. 部署 ERC20、ERC721、NFTMarket
        ////////////////////////////////////////

        // ⚠️ 根据你自己的 MyERC20 / MyERC721 构造函数改参数
        // 比如如果是 ERC20("name","symbol") 就写进去
        MyERC20 paymentToken = new MyERC20("PaymentToken", "PTK");
        MyERC721 nft = new MyERC721("MyNFT", "NFT");

        NFTMarket market = new NFTMarket(
            address(paymentToken),
            address(nft)
        );

        ////////////////////////////////////////
        // 3. 打印地址，方便后续前端/脚本使用
        ////////////////////////////////////////

        console2.log("=== Deploy Result ===");
        console2.log("paymentToken (MyERC20):", address(paymentToken));
        console2.log("nft         (MyERC721):", address(nft));
        console2.log("market      (NFTMarket):", address(market));

        vm.stopBroadcast();
    }
}
