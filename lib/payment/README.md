# 支付模块说明文档

## 📋 概述

支付模块为Vanguard公寓管理系统提供两种支付方式：
1. **区块链支付** - 使用以太坊网络（Ganache测试环境）
2. **传统支付** - 使用Stripe支付网关

## 🏗️ 文件结构

```
lib/payment/
├── models/
│   └── transaction_model.dart      # 交易数据模型
├── services/
│   ├── blockchain_service.dart     # 区块链支付服务
│   └── payment_gateway_service.dart # Stripe支付服务
├── controllers/
│   └── payment_controller.dart    # 支付业务逻辑控制器
└── ui/
    ├── payment_home.dart          # 支付主页
    ├── payment_method_selection.dart # 支付方法选择页面
    └── payment_history.dart        # 支付历史页面
```

## ⚙️ 配置说明

### 1. Ganache配置

支付模块已配置为使用Ganache本地测试网络：
- **RPC URL**: `http://0.0.0.0:7545`
- **Network ID**: `5777`

如需修改配置，请编辑 `lib/payment/services/blockchain_service.dart`：

```dart
static const String rpcUrl = 'http://0.0.0.0:7545';
static const int chainId = 5777;
```

### 2. Stripe配置

**重要**: 在生产环境中，必须配置真实的Stripe API密钥。

编辑 `lib/payment/services/payment_gateway_service.dart`：

```dart
static const String _stripePublishableKey = 'pk_test_your_publishable_key';
static const String _stripeSecretKey = 'sk_test_your_secret_key';
```

**安全提示**:
- 永远不要将Secret Key存储在客户端代码中
- 应该使用后端API来处理支付意图创建和确认
- 当前实现仅作为示例，生产环境需要后端支持

### 3. Firebase Firestore集合

支付模块使用以下Firestore集合：
- `transactions` - 存储所有交易记录

集合结构请参考 `transaction_model.dart` 中的 `toFirestore()` 方法。

## 🚀 使用方法

### 访问支付模块

1. 从用户主页点击"Payment"卡片
2. 或直接导航到 `/user/payment`

### 区块链支付流程

1. 在支付主页选择待支付费用
2. 选择"区块链支付"方式
3. 输入：
   - 私钥（64位十六进制字符，不带0x前缀）
   - 接收地址（管理方以太坊地址）
4. 确认支付
5. 系统将：
   - 发送以太坊交易到Ganache网络
   - 等待交易确认（最多30秒）
   - 保存交易哈希和区块信息到Firestore

### 传统支付流程（Stripe）

**注意**: 当前实现需要配置Stripe密钥和实现支付表单。

1. 选择"信用卡/借记卡"支付方式
2. 使用Stripe支付表单输入卡信息
3. 确认支付
4. 系统将保存支付收据ID到Firestore

## 🔒 安全注意事项

### 私钥管理

**重要**: 当前实现要求用户输入私钥，这在生产环境中是不安全的。

**推荐方案**:
1. 使用Web3钱包（如MetaMask）进行签名
2. 使用硬件钱包
3. 使用后端服务管理私钥（需要额外的安全措施）

### 数据加密

- 敏感数据（如私钥）不应存储在Firestore中
- 考虑使用Firebase Security Rules保护交易数据
- 实现适当的访问控制

## 📊 交易记录

所有交易记录存储在Firestore的 `transactions` 集合中，包含：
- 用户ID和居民ID
- 支付金额和费用类型
- 支付方法和状态
- 区块链交易哈希（如适用）
- Stripe收据ID（如适用）
- 时间戳和元数据

## 🧪 测试

### Ganache测试账户

1. 启动Ganache
2. 从Ganache界面获取测试账户的私钥和地址
3. 确保账户有足够的ETH余额
4. 使用测试账户进行支付测试

### 测试流程

1. 确保Ganache正在运行
2. 在应用中导航到支付页面
3. 选择区块链支付
4. 输入Ganache测试账户的私钥
5. 输入接收地址（可以是另一个Ganache账户）
6. 确认支付并查看交易历史

## 🔧 故障排除

### 区块链支付失败

- 检查Ganache是否正在运行
- 验证RPC URL是否正确
- 确认账户有足够的ETH余额
- 检查私钥格式是否正确（64位十六进制）

### Stripe支付失败

- 确认已配置有效的Stripe API密钥
- 检查网络连接
- 验证支付金额格式

### Firestore错误

- 检查Firebase配置是否正确
- 验证用户已登录
- 检查Firestore安全规则

## 📝 待实现功能

- [ ] Web3钱包集成（MetaMask等）
- [ ] Stripe支付表单完整实现
- [ ] PayPal支付集成
- [ ] 支付通知和提醒
- [ ] 滞纳金自动计算
- [ ] 支付报表和统计
- [ ] 退款功能

## 📞 支持

如有问题，请联系开发团队。
