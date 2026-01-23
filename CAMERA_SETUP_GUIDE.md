# 相机权限配置指南

## ✅ 已完成的配置

### Android 配置
已在 `android/app/src/main/AndroidManifest.xml` 中添加：
- ✅ 相机权限：`android.permission.CAMERA`
- ✅ 相机硬件特性声明（可选但推荐）

### QR 扫描页面
已在 `lib/security/qr_scanner_page.dart` 中添加：
- ✅ 相机权限检查和错误处理
- ✅ 友好的权限被拒绝提示界面
- ✅ 自动权限请求处理

---

## 📱 iOS 配置（如果项目包含 iOS）

如果你的项目包含 iOS 平台，需要在 `ios/Runner/Info.plist` 中添加以下配置：

### 步骤 1: 打开 Info.plist
找到文件：`ios/Runner/Info.plist`

### 步骤 2: 添加相机权限说明
在 `<dict>` 标签内添加：

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan visitor QR codes for security purposes.</string>
```

### 完整示例（Info.plist 片段）：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 其他配置... -->
    
    <!-- 相机权限说明 -->
    <key>NSCameraUsageDescription</key>
    <string>This app needs camera access to scan visitor QR codes for security purposes.</string>
    
    <!-- 其他配置... -->
</dict>
</plist>
```

---

## 🔧 如何验证配置

### Android
1. 运行应用：`flutter run`
2. 导航到保安页面 → QR 扫描
3. 首次使用时，系统会自动弹出相机权限请求
4. 如果权限被拒绝，会显示友好的错误提示界面

### iOS（如果适用）
1. 运行应用：`flutter run`
2. 首次访问相机时，系统会显示权限请求对话框
3. 对话框会显示你在 Info.plist 中设置的说明文字

---

## 🐛 常见问题

### 问题 1: Android 上相机无法启动
**解决方案**:
- 检查 `AndroidManifest.xml` 中是否已添加相机权限
- 确保设备有相机硬件
- 检查是否有其他应用正在使用相机

### 问题 2: iOS 上权限请求不显示
**解决方案**:
- 确认 `Info.plist` 中已添加 `NSCameraUsageDescription`
- 清理构建：`flutter clean` 然后重新运行
- 检查 Xcode 项目设置

### 问题 3: 权限被拒绝后无法重新请求
**解决方案**:
- Android: 引导用户到设置中手动授予权限
- iOS: 用户需要在设置中手动授予权限
- 代码中已添加"重试"按钮，点击后会尝试重新启动相机

---

## 📝 技术说明

### mobile_scanner 包
- 使用 `mobile_scanner: ^5.1.1`
- Android: 使用 CameraX API
- iOS: 使用 AVFoundation
- 自动处理大部分权限请求逻辑

### 权限处理流程
1. 应用启动 QR 扫描页面
2. `MobileScannerController.start()` 被调用
3. 如果权限未授予，系统自动弹出权限请求
4. 用户授予/拒绝权限
5. 根据结果显示相机预览或错误界面

---

## ✅ 测试清单

- [ ] Android 设备上相机可以正常启动
- [ ] 首次使用时权限请求正常弹出
- [ ] 权限被拒绝后显示友好的错误提示
- [ ] 闪光灯开关功能正常
- [ ] 前后摄像头切换功能正常
- [ ] QR 码扫描功能正常
- [ ] （如果适用）iOS 设备上相机可以正常启动

---

## 🚀 下一步

1. 运行应用并测试相机功能
2. 如果遇到问题，参考"常见问题"部分
3. 如果项目包含 iOS，确保添加 Info.plist 配置
