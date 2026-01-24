# AI聊天机器人设置指南

## 概述

AI聊天机器人是一个智能助手，可以帮助居民了解和使用Vanguard物业管理系统的所有功能。它能够回答关于系统使用的各种问题。

## 功能特性

- ✅ 理解系统所有功能（访客管理、设施预订、维护请求、支付等）
- ✅ 回答居民关于系统使用的任何问题
- ✅ 提供快速问题模板
- ✅ 友好的中文界面
- ✅ 对话历史记录
- ✅ 备用回复机制（当API不可用时）

## 配置步骤

### 1. 获取AI API密钥

您可以选择使用以下任一AI服务：

#### 选项A：OpenAI API（推荐）

1. 访问 [OpenAI官网](https://platform.openai.com/)
2. 注册账号并创建API密钥
3. 复制您的API密钥

#### 选项B：Google Gemini API

1. 访问 [Google AI Studio](https://makersuite.google.com/app/apikey)
2. 创建API密钥
3. 复制您的API密钥

### 2. 配置API密钥

**方法1：直接在代码中配置（仅用于测试）**

编辑 `lib/services/ai_chatbot_service.dart` 文件：

```dart
// 对于OpenAI
static const String _apiKey = 'YOUR_OPENAI_API_KEY';

// 或对于Gemini
static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY';
```

**方法2：使用环境变量（推荐用于生产环境）**

1. 创建 `.env` 文件（如果还没有）
2. 添加API密钥：
   ```
   OPENAI_API_KEY=your_api_key_here
   ```
3. 使用 `flutter_dotenv` 包读取环境变量

**方法3：使用Firebase Functions（最安全）**

1. 在 `functions/src/index.ts` 中创建AI聊天端点
2. 将API密钥存储在Firebase Functions环境变量中
3. 从Flutter应用调用Firebase Functions端点

### 3. 更新API配置

如果使用Gemini API，需要修改 `ai_chatbot_service.dart` 中的 `sendMessage` 方法，调用 `sendMessageWithGemini` 而不是 `sendMessage`。

## 系统知识库

AI聊天机器人包含完整的系统知识库，涵盖：

- 访客管理（注册、审核、QR码）
- 设施预订（查看、预订、状态）
- 维护请求（提交、跟踪、状态）
- 支付中心（查看费用、支付方式）
- 与保安聊天
- 居民论坛
- 紧急情况报告
- 反馈提交
- 个人资料管理
- 人脸识别注册
- 租户管理（仅业主）

知识库位于 `lib/services/ai_chatbot_service.dart` 的 `getSystemKnowledge()` 方法中，可以根据需要更新。

## 使用说明

### 对于居民

1. 在主页面点击"AI Assistant"按钮
2. 查看欢迎消息和快速问题
3. 输入您的问题，AI会立即回答
4. 可以点击右上角的帮助图标查看快速问题模板

### 常见问题示例

- "如何注册访客？"
- "如何预订设施？"
- "如何提交维护请求？"
- "如何支付物业费用？"
- "如何联系保安？"

## 备用回复机制

如果AI API不可用或发生错误，系统会自动使用备用回复机制。备用回复基于关键词匹配，可以回答常见问题。

## 安全注意事项

⚠️ **重要**：不要将API密钥提交到版本控制系统（如Git）

1. 将API密钥添加到 `.gitignore`
2. 使用环境变量或Firebase Functions存储密钥
3. 定期轮换API密钥
4. 监控API使用情况，避免超出配额

## 成本考虑

- OpenAI GPT-3.5-turbo：相对便宜，适合大多数用例
- OpenAI GPT-4：更准确但更昂贵
- Google Gemini：免费额度较大

建议：
- 开发/测试：使用备用回复机制或免费API
- 生产环境：使用GPT-3.5-turbo或Gemini

## 故障排除

### AI不响应

1. 检查API密钥是否正确配置
2. 检查网络连接
3. 查看控制台错误日志
4. 验证API配额是否已用完

### 回答不准确

1. 更新 `getSystemKnowledge()` 中的知识库
2. 调整AI模型的temperature参数
3. 添加更多示例对话到知识库

### 备用回复不工作

1. 检查 `_getFallbackResponse` 方法
2. 添加更多关键词匹配规则

## 未来改进

- [ ] 支持语音输入
- [ ] 支持图片识别
- [ ] 多语言支持
- [ ] 上下文记忆（跨会话）
- [ ] 集成实际系统数据（如查看实际预订状态）
- [ ] 支持操作执行（如直接创建预订）

## 技术支持

如有问题，请联系开发团队或查看项目文档。
