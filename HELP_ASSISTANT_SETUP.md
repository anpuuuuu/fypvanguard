# Help Assistant 真实 AI 配置指南（Groq）

帮助助手（Help Assistant）使用 **Groq API** 实现真实 AI 对话。未配置 API Key 时会使用内置关键词回复。

---

## 第一步：获取 Groq API Key

1. 打开 [Groq 控制台](https://console.groq.com/)
2. 登录或注册账号
3. 进入 **API Keys**，创建并复制 Key（通常以 `gsk_` 开头）
4. Groq 提供较慷慨的免费额度，且推理速度快

---

## 第二步：配置 API Key

### 方法一：粘贴到代码（简单）

1. 打开 `lib/services/help_assistant_service.dart`
2. 找到 `_apiKeyPasteHere = ''`
3. 在引号内粘贴你的 Groq Key，例如：`_apiKeyPasteHere = 'gsk_你的Key';`
4. 保存后运行应用

### 方法二：dart-define（不写进代码）

```bash
flutter run --dart-define=HELP_ASSISTANT_API_KEY=你的Groq的Key
```

Windows PowerShell：

```powershell
flutter run --dart-define=HELP_ASSISTANT_API_KEY=gsk_xxxxxxxx
```

### 在 Android Studio / Cursor 中配置

1. **Run → Edit Configurations**
2. 选中 Flutter 运行配置
3. 在 **Additional run args** 填入：`--dart-define=HELP_ASSISTANT_API_KEY=你的Key`
4. 保存后点击 Run

---

## 如何确认已生效

1. 运行应用并进入 **Help Assistant**
2. 随便问一句（例如 “How do I book the gym?”）
3. 若返回自然、贴合问题的回答，说明已在使用 Groq AI

未配置 Key 或 Key 错误时，会退回内置关键词回复。

---

## 安全提醒

- 不要将 API Key 提交到 Git 或公开仓库
- 生产环境建议用后端（如 Firebase Functions）代理请求，Key 只放在服务端
- 定期在 [Groq 控制台](https://console.groq.com/) 轮换/撤销 Key

---

## 故障排除

| 现象 | 可能原因 | 处理 |
|------|----------|------|
| 回答像是固定模板 | 未配置 Key 或未生效 | 确认 Key 已粘贴或 dart-define 已传入，完整重启应用 |
| 401 Unauthorized | Key 错误或已撤销 | 在 console.groq.com 检查 Key，重新创建并替换 |
| 429 / 限流 | 超出免费额度或请求过频 | 稍后再试或查看 Groq 用量 |
| 网络错误 | 无法访问 api.groq.com | 检查网络、代理或防火墙 |

如有其他问题，可查看控制台完整报错或联系开发团队。
