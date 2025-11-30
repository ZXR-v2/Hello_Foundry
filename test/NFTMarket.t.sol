// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";

// 假设你的合约路径如下，请根据自己仓库目录调整
import "../src/NFTMarket.sol";
import "../src/MyERC20.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @dev 简单的测试用 NFT 合约
contract MockNFT is ERC721 {
    uint256 public nextId;

    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

/// @dev 测试合约
contract NFTMarketTest is Test {
    // 事件签名需与 NFTMarket.sol 中一致
    event NFTListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    event NFTSold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );

    NFTMarket public market;
    MockNFT public nft;
    MyERC20 public paymentToken;

    address public seller = address(0xAAA1);
    address public buyer  = address(0xBBB2);

    uint256 public constant TOKEN_ID = 1;

    function setUp() public {
        // 部署 NFT 与 Token
        nft = new MockNFT();
        paymentToken = new MyERC20("MyToken", "MTK");

        // 部署 Market 合约（根据你的构造函数调整参数）
        market = new NFTMarket(address(paymentToken), address(nft));

        // 给 seller 铸造 NFT
        nft.mint(seller, TOKEN_ID);

        // 把初始 Token 分发给若干地址（MyERC20 构造函数中把总代币给了本测试合约）
        uint256 initialAmount = 1_000_000 ether;
        deal(address(paymentToken), seller, initialAmount);
        deal(address(paymentToken), buyer, initialAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        上架 NFT 测试
    //////////////////////////////////////////////////////////////*/

    /// @dev 上架成功，断言事件与状态
    function test_List_Success() public {
        uint256 price = 100 ether;

        // seller 先授权 Market 转移 NFT
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID);

        // 期望触发 NFTListed 事件
        vm.expectEmit(true, true, true, true);
        emit NFTListed(TOKEN_ID, seller, price);

        market.list(TOKEN_ID, price);
        vm.stopPrank();

        // 校验 listing 状态
        (address lSeller, uint256 lPrice, bool isActive) =
            market.listings(TOKEN_ID);

        assertEq(lSeller, seller, "seller mismatch");
        assertEq(lPrice, price, "price mismatch");
        assertTrue(isActive, "listing should be active");
    }

    /// @dev 非 NFT 持有人上架，应该失败
    function test_List_Fails_NotOwner() public {
        uint256 price = 100 ether;

        // buyer 尝试上架自己不拥有的 NFT
        vm.prank(buyer);
        vm.expectRevert(bytes("NFTMarket: caller is not token owner"));
        market.list(TOKEN_ID, price);
    }

    /// @dev 上架价格为 0，应该失败（如你的合约未限制，可按需修改）
    function test_List_Fails_ZeroPrice() public {
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID);
        vm.expectRevert(bytes("NFTMarket: price must be greater than 0"));
        market.list(TOKEN_ID, 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        购买 NFT 测试
    //////////////////////////////////////////////////////////////*/

    /// @dev 辅助函数：先由 seller 上架 NFT
    function _listFor(uint256 price) internal {
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID);
        market.list(TOKEN_ID, price);
        vm.stopPrank();
    }

    /// @dev 使用 transferWithCallback 成功购买 NFT（正常情况）
    function test_Buy_Success_WithCallback() public {
        uint256 price = 100 ether;
        _listFor(price);

        uint256 amount = price; // 刚好付够
        uint256 sellerBefore = paymentToken.balanceOf(seller);
        uint256 buyerBefore  = paymentToken.balanceOf(buyer);

        // 期望触发 NFTSold 事件
        vm.expectEmit(true, true, true, true);
        emit NFTSold(TOKEN_ID, seller, buyer, price);

        // buyer 使用 MyERC20 的 transferWithCallback 支付并购买
        vm.prank(buyer);
        paymentToken.transferWithCallback(
            address(market),
            amount,
            abi.encode(TOKEN_ID)
        );

        // 校验 Token 结算
        uint256 sellerAfter = paymentToken.balanceOf(seller);
        uint256 buyerAfter  = paymentToken.balanceOf(buyer);

        assertEq(sellerAfter - sellerBefore, price, "seller should receive price");
        assertEq(buyerBefore - buyerAfter, price, "buyer should pay price");

        // 校验 NFT 属主变化
        assertEq(nft.ownerOf(TOKEN_ID), buyer, "buyer should own NFT now");

        // 校验 listing 已失效
        (, , bool isActive) = market.listings(TOKEN_ID);
        assertFalse(isActive, "listing should be inactive");
    }

    /// @dev 自己购买自己的 NFT，应该失败
    function test_Buy_Fails_BuyOwnNFT() public {
        uint256 price = 100 ether;
        _listFor(price);

        // seller 自己付 Token 买自己挂的 NFT
        uint256 amount = price;

        vm.prank(seller);
        vm.expectRevert(bytes("NFTMarket: buyer is seller"));
        paymentToken.transferWithCallback(
            address(market),
            amount,
            abi.encode(TOKEN_ID)
        );
    }

    /// @dev NFT 被重复购买：第二次购买应该失败
    function test_Buy_Fails_RepeatedBuy() public {
        uint256 price = 100 ether;
        _listFor(price);

        // 第一次购买成功
        vm.prank(buyer);
        paymentToken.transferWithCallback(
            address(market),
            price,
            abi.encode(TOKEN_ID)
        );

        // 第二次再买同一个 tokenId，应失败：NFT 已下架
        address anotherBuyer = address(0xCCC3);
        paymentToken.transfer(anotherBuyer, 1_000_000 ether);

        vm.prank(anotherBuyer);
        vm.expectRevert(bytes("NFTMarket: NFT not listed"));
        paymentToken.transferWithCallback(
            address(market),
            price,
            abi.encode(TOKEN_ID)
        );
    }

    /// @dev 支付 Token 不足：应失败，错误信息断言
    function test_Buy_Fails_InsufficientPayment() public {
        uint256 price = 100 ether;
        _listFor(price);

        uint256 amount = price - 1 ether; // 少一点

        vm.prank(buyer);
        vm.expectRevert(bytes("NFTMarket: insufficient payment"));
        paymentToken.transferWithCallback(
            address(market),
            amount,
            abi.encode(TOKEN_ID)
        );
    }

    /// @dev 支付 Token 过多：应成功，且多余部分退款给 buyer
    function test_Buy_Success_OverpayRefund() public {
        uint256 price = 100 ether;
        _listFor(price);

        uint256 amount = price + 50 ether; // 多付 50
        uint256 sellerBefore = paymentToken.balanceOf(seller);
        uint256 buyerBefore  = paymentToken.balanceOf(buyer);

        vm.prank(buyer);
        paymentToken.transferWithCallback(
            address(market),
            amount,
            abi.encode(TOKEN_ID)
        );

        uint256 sellerAfter = paymentToken.balanceOf(seller);
        uint256 buyerAfter  = paymentToken.balanceOf(buyer);

        // 卖家只收到 price
        assertEq(sellerAfter - sellerBefore, price, "seller should get price only");
        // 买家实际支出为 price，多余部分退回
        assertEq(buyerBefore - buyerAfter, price, "buyer should be refunded extra");

        // 市场合约不应持有 Token
        assertEq(
            paymentToken.balanceOf(address(market)),
            0,
            "market should not hold tokens after trade"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        模糊测试（Fuzz Test）
    //////////////////////////////////////////////////////////////*/

    /// @dev 随机价格（0.01 ~ 10000 Token）+ 随机买家地址模糊测试
    function testFuzz_ListAndBuy_WithRandomPriceAndBuyer(
        uint128 rawPrice,
        address randomBuyer
    ) public {
        // 过滤掉 0 地址，避免 buyer == address(0)
        vm.assume(randomBuyer != address(0));
        // 避免买家就是 seller（如果你允许也可以不排除）
        vm.assume(randomBuyer != seller);

        // 价格范围：0.01 ~ 10000（以 18 位小数计）
        // 思路：先把 rawPrice 映射到 1 ~ 1_000_000（表示 0.01 步长），再乘以 1e16
        uint256 humanPrice = bound(uint256(rawPrice), 1, 1_000_000); // 表示 0.01 单位
        uint256 price = humanPrice * 1e16; // 0.01 * 1e18 = 1e16

        // 给 randomBuyer 足够 Token
        deal(address(paymentToken), randomBuyer, 1_000_000_000 ether);

        // 上架
        _listFor(price);

        // 随机买家支付刚好 price
        vm.prank(randomBuyer);
        paymentToken.transferWithCallback(
            address(market),
            price,
            abi.encode(TOKEN_ID)
        );

        // 校验 NFT 属主
        assertEq(nft.ownerOf(TOKEN_ID), randomBuyer, "randomBuyer should own NFT");

        // 校验 Market 不留 Token（如果你的合约有退多余款逻辑，该断言始终成立）
        assertEq(
            paymentToken.balanceOf(address(market)),
            0,
            "market should not hold tokens"
        );
    }

    /*//////////////////////////////////////////////////////////////
                「可选」不变量测试（简单版本示例）
    //////////////////////////////////////////////////////////////*/

    /// @dev 简单版：验证在一轮买卖之后，Market 不持有 Token
    /// 如果要做真正的 Foundry invariant，可以再建一个 Invariant 测试合约，
    /// 使用 targetContract/targetSelector 配合随机调度。
    function test_MarketNeverHoldsTokenAfterTrades() public {
        uint256 price = 50 ether;

        // 上架 & 购买一次
        test_Buy_Success_OverpayRefund();

        // 再上架另一次（重新铸一个 NFT）
        uint256 tokenId2 = 2;
        nft.mint(seller, tokenId2);

        vm.startPrank(seller);
        nft.approve(address(market), tokenId2);
        market.list(tokenId2, price);
        vm.stopPrank();

        // 让 buyer 再买一次
        vm.prank(buyer);
        paymentToken.transferWithCallback(
            address(market),
            price,
            abi.encode(tokenId2)
        );

        // 断言：Market 仍不持有 Token
        assertEq(
            paymentToken.balanceOf(address(market)),
            0,
            "market must never hold tokens"
        );
    }
}
