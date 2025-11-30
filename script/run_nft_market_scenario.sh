#!/usr/bin/env bash
set -euo pipefail

###############################
# 基本配置（请根据自己情况修改）
###############################

# RPC 节点（本地 anvil）
RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"

# 合约地址（来自 DeployNFTMarket.s.sol 的输出）
PAYMENT_TOKEN="0x5FbDB2315678afecb367f032d93F642f64180aa3"   # MyERC20
NFT_CONTRACT="0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"    # MyERC721
MARKET_CONTRACT="0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0" # NFTMarket

# 使用的私钥（默认使用 anvil 的前几个账号）
# ⚠️ 这些私钥只用于本地测试，不要在主网使用
DEPLOYER_PK="${DEPLOYER_PK:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
SELLER_PK="${SELLER_PK:-0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}"
BUYER1_PK="${BUYER1_PK:-0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a}"
BUYER2_PK="${BUYER2_PK:-0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6}"

# 价格 & 数量（18 位精度）
PRICE_WEI="100000000000000000000"        # 100 * 1e18
BUY_AMOUNT_WEI="1000000000000000000000"  # 1000 * 1e18

# NFT 元数据
TOKEN_URI="zxr"
TOKEN_ID="0"  # 你的 MyERC721 第一次 mint 出来的 tokenId 是 0（从日志里已经验证过）


########################################
# 小工具：打印标题
########################################
step() {
  echo
  echo "==================== $1 ===================="
}

########################################
# 推导地址
########################################
DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PK")
SELLER_ADDR=$(cast wallet address "$SELLER_PK")
BUYER1_ADDR=$(cast wallet address "$BUYER1_PK")
BUYER2_ADDR=$(cast wallet address "$BUYER2_PK")

echo "RPC_URL        = $RPC_URL"
echo "PAYMENT_TOKEN  = $PAYMENT_TOKEN"
echo "NFT_CONTRACT   = $NFT_CONTRACT"
echo "MARKET_CONTRACT= $MARKET_CONTRACT"
echo "DEPLOYER_ADDR  = $DEPLOYER_ADDR"
echo "SELLER_ADDR    = $SELLER_ADDR"
echo "BUYER1_ADDR    = $BUYER1_ADDR"
echo "BUYER2_ADDR    = $BUYER2_ADDR"

########################################
# ① 给 BUYER1 转 1000 代币（用于 buyNFT）
########################################
step "① DEPLOYER 给 BUYER1 转 1000 代币（用于 buyNFT）"

cast send "$PAYMENT_TOKEN" \
  "transfer(address,uint256)" \
  "$BUYER1_ADDR" "$BUY_AMOUNT_WEI" \
  --private-key "$DEPLOYER_PK" \
  --rpc-url "$RPC_URL"

echo "Buyer1 代币余额："
cast call "$PAYMENT_TOKEN" \
  "balanceOf(address)(uint256)" \
  "$BUYER1_ADDR" \
  --rpc-url "$RPC_URL"

########################################
# ② 给 BUYER2 转 1000 代币（用于回调购买）
########################################
step "② DEPLOYER 给 BUYER2 再转 1000 代币（用于回调购买）"

cast send "$PAYMENT_TOKEN" \
  "transfer(address,uint256)" \
  "$BUYER2_ADDR" "$BUY_AMOUNT_WEI" \
  --private-key "$DEPLOYER_PK" \
  --rpc-url "$RPC_URL"

echo "Buyer2 代币余额："
cast call "$PAYMENT_TOKEN" \
  "balanceOf(address)(uint256)" \
  "$BUYER2_ADDR" \
  --rpc-url "$RPC_URL"

########################################
# ③ 用 DEPLOYER mint 一个 NFT 给 SELLER
########################################
step "③ DEPLOYER mint 一个 NFT 给 SELLER"

cast send "$NFT_CONTRACT" \
  "mint(address,string)" \
  "$SELLER_ADDR" "$TOKEN_URI" \
  --private-key "$DEPLOYER_PK" \
  --rpc-url "$RPC_URL"

echo "TOKEN_ID = $TOKEN_ID 的当前 owner："
cast call "$NFT_CONTRACT" \
  "ownerOf(uint256)(address)" \
  "$TOKEN_ID" \
  --rpc-url "$RPC_URL"

########################################
# ④ SELLER 将 NFT 授权给 Market 合约
########################################
step "④ SELLER 将 NFT 授权给 Market 合约"

cast send "$NFT_CONTRACT" \
  "approve(address,uint256)" \
  "$MARKET_CONTRACT" "$TOKEN_ID" \
  --private-key "$SELLER_PK" \
  --rpc-url "$RPC_URL"

########################################
# ⑤ SELLER 上架 NFT（list）
########################################
step "⑤ SELLER 调用 list 上架 NFT"

cast send "$MARKET_CONTRACT" \
  "list(uint256,uint256)" \
  "$TOKEN_ID" "$PRICE_WEI" \
  --private-key "$SELLER_PK" \
  --rpc-url "$RPC_URL"

########################################
# ⑥ BUYER1 授权 ERC20 给 Market
########################################
step "⑥ BUYER1 授权 Market 使用 100 个代币"

cast send "$PAYMENT_TOKEN" \
  "approve(address,uint256)" \
  "$MARKET_CONTRACT" "$PRICE_WEI" \
  --private-key "$BUYER1_PK" \
  --rpc-url "$RPC_URL"

########################################
# ⑦ BUYER1 用 buyNFT 购买 NFT
########################################
step "⑦ BUYER1 调用 buyNFT 购买 NFT"

cast send "$MARKET_CONTRACT" \
  "buyNFT(uint256)" \
  "$TOKEN_ID" \
  --private-key "$BUYER1_PK" \
  --rpc-url "$RPC_URL"

echo "after buyNFT，NFT owner："
cast call "$NFT_CONTRACT" \
  "ownerOf(uint256)(address)" \
  "$TOKEN_ID" \
  --rpc-url "$RPC_URL"

########################################
# ⑧ BUYER1 作为新 owner 再次上架 NFT
########################################
step "⑧ BUYER1 再次上架 NFT（为回调购买做准备）"

# 先给 Market 授权 NFT
cast send "$NFT_CONTRACT" \
  "approve(address,uint256)" \
  "$MARKET_CONTRACT" "$TOKEN_ID" \
  --private-key "$BUYER1_PK" \
  --rpc-url "$RPC_URL"

# 再次上架
cast send "$MARKET_CONTRACT" \
  "list(uint256,uint256)" \
  "$TOKEN_ID" "$PRICE_WEI" \
  --private-key "$BUYER1_PK" \
  --rpc-url "$RPC_URL"

########################################
# ⑨ BUYER2 使用 transferWithCallback 触发 tokensReceived 回调购买
########################################
step "⑨ BUYER2 使用 transferWithCallback 触发 tokensReceived 回调购买"

# data = abi.encode(tokenId)
DATA=$(cast abi-encode "f(uint256)" "$TOKEN_ID")

cast send "$PAYMENT_TOKEN" \
  "transferWithCallback(address,uint256,bytes)" \
  "$MARKET_CONTRACT" "$PRICE_WEI" "$DATA" \
  --private-key "$BUYER2_PK" \
  --rpc-url "$RPC_URL"

echo "after transferWithCallback，NFT owner："
cast call "$NFT_CONTRACT" \
  "ownerOf(uint256)(address)" \
  "$TOKEN_ID" \
  --rpc-url "$RPC_URL"

step "流程完成，可以在监听脚本中查看所有事件日志 🎉"
