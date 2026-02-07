# 支付模块说明文档

## 📋 概述

支付模块为Vanguard公寓管理系统提供两种支付方式：
1. **区块链支付** - 使用以太坊网络（Ganache测试环境）
2. **卡片支付（PayPal 沙盒）** - 使用 PayPal Sandbox，不真实扣款；支付成功后生成发票并发送至用户邮箱

## 🏗️ 文件结构

```
lib/payment/
├── models/
│   └── transaction_model.dart      # 交易数据模型
├── services/
│   ├── blockchain_service.dart     # 区块链支付服务
│   └── payment_gateway_service.dart # PayPal Sandbox 支付服务（模拟）
├── controllers/
│   └── payment_controller.dart    # 支付业务逻辑控制器
└── ui/
    ├── payment_home.dart          # 支付主页
    ├── payment_method_selection.dart # 支付方法选择页面
    └── payment_history.dart        # 支付历史页面
```

## ⚙️ 配置说明

### 1. Ganache 配置（支持本机演示 + 多设备同一链）

- **本机 / 演示 PC 使用方式**（推荐：在同一台电脑上演示时余额在该机 Ganache 扣除）：
  - 应用会**优先连接本机 Ganache**（localhost 或 Android 模拟器 10.0.2.2:7545）。若本机 Ganache 已启动且可达，则使用本机链，支付成功后会**在该 PC 的 Ganache 上扣款**。
  - **演示步骤**：在演示用的那台 PC 上先打开 Ganache，再运行应用；进入区块链支付、选账户并输入私钥后支付，即可在该 PC 的 Ganache 界面看到余额扣除。
- **多台电脑 / 多设备共用一条链**（可选）：
  - 当本机 Ganache **不可达**时（例如在手机或未开 Ganache 的 PC 上），应用会尝试使用 Firestore 中的 **`settings/blockchain.rpcUrl`** 作为备用。
  - 在 Firestore 创建文档 **`settings/blockchain`**，可设置：
    - **`rpcUrl`**：例如 `http://192.168.1.100:7545`（运行 Ganache 的主机 IP），供无本机 Ganache 的设备使用。
    - **`managementWalletAddress`**（可选）：收款地址，不填则用代码默认。
  - 在运行 Ganache 的主机上将 RPC Server 设为 **HTTP://0.0.0.0:7545** 并放行防火墙 7545。
- **Network ID**: `5777`

### 2. PayPal Sandbox

**方式一：使用 PayPal 沙盒账户支付（真实沙盒流程）**

- 用户在应用内选择「Pay with PayPal (Sandbox account)」，会跳转到 PayPal 沙盒页面，使用沙盒账户（如 `sb-xxx@personal.example.com`）登录并批准付款，返回应用后点击「I've completed payment」完成。
- 需在 **Firebase Cloud Functions** 中配置环境变量（Google Cloud Console 或 Firebase 控制台）：
  - `PAYPAL_CLIENT_ID`：PayPal 开发者后台沙盒应用的 Client ID
  - `PAYPAL_CLIENT_SECRET`：该沙盒应用的 Secret
- 部署后调用 `createPayPalOrder`、`capturePayPalOrder` 会使用上述配置与 PayPal 沙盒 API 通信。

**方式二：卡片支付（应用内模拟）**

- 不调用 PayPal API，仅校验卡号格式（Luhn）、有效期、CVV，模拟成功并生成发票。
- 测试卡号示例：`4012888888881881`，有效期填未来日期，CVV 填 3 或 4 位数字。

### 3. 发票与邮件

- 支付成功后在 Firestore 的 `invoices` 集合中创建发票
- 若已配置 Cloud Functions 的 SMTP（如 Gmail），会通过 `onInvoiceCreated` 将发票发送至用户邮箱
- 配置方式：在 Firebase 项目环境变量中设置 `SMTP_USER`、`SMTP_APP_PASSWORD`（如 Gmail 应用专用密码）

### 4. Firebase Firestore 集合

支付模块使用以下 Firestore 集合：
- `transactions` - 存储所有交易记录
- `invoices` - 存储发票（卡片/PayPal 支付成功后创建）

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
