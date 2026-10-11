# Mac App Store 发布

当前产品名称为「晾贴 / PegNest」，本机 Bundle ID 为 `local.PegNest`，不能将这个临时标识直接用于商店。正式 Bundle ID `<registered-bundle-id>` 已在 Apple Developer 注册；App Store 名称尚未预留，公开搜索不构成商标清查。

## 工程

打开 `PegNest.xcodeproj`，共享 Scheme 为 PegNest，最低 macOS 14。Debug 和 Release 均启用沙盒。发布构建包含 Apple silicon 和 Intel。

Entitlements 仅包含 App Sandbox、用户选择文件读写、app-scoped bookmarks。不使用辅助功能、屏幕录制、Apple Events、网络或私有 WindowServer API。全屏显示使用公开的窗口 collectionBehavior，由系统决定 Space 行为。

PrivacyInfo.xcprivacy 声明 UserDefaults（CA92.1）、应用容器文件元数据（C617.1）和用户授权目录元数据（3B52.1）；没有数据收集或跟踪声明。依据：[Apple required-reason API 文档](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)。提交前按最终 API 使用情况复核。

## Archive 与导出

设置实际开发者 Team ID 和已注册 Bundle ID 后运行：

```sh
DEVELOPMENT_TEAM='<实际 Team ID>' PRODUCT_BUNDLE_IDENTIFIER='<已注册 Bundle ID>' scripts/archive-app.sh
DEVELOPMENT_TEAM='<实际 Team ID>' scripts/export-app-store.sh
```

脚本不会上传，也不会自动签署协议。Archive 使用 Apple Development；Export 由 Xcode 的自动签名流程生成商店分发包，需要账号中实际可用的证书和描述文件。正式 app 名称、版权运营主体、价格、地区、年龄分级和加密回答必须依据实际账号与最终实现填写。

## 发布前所需资料

- 有权限的 Apple Developer / App Store Connect 账号、有效会员及必要协议。
- 可注册 Bundle ID、可用应用名称、正确签名和描述文件。
- 实际支持联系方式、公开支持页面和隐私政策 URL；应用内增加最终在线链接。
- 定价、销售地区、年龄分级、版权主体和加密声明。
- 真实应用截图与复核完成的验收记录。

应用内打包原作者 MIT 许可并说明独立修改来源。上游名称仅用于来源说明；图标和宣传截图不使用未授权上游素材。授权依据见 [LICENSE](../LICENSE)。

## 审核说明草案

PegNest 是本机剪贴板历史与截图目录工具。使用菜单主动开启剪贴板历史，再复制文字或图片；鼠标停在菜单栏或 Control–Option–T 显示挂绳，点击卡片重新复制。选择截图目录后新图片及录屏出现于挂绳，原文件保留。复制和历史存储均在本机，应用不向开发者传输内容，无需账号。

这段说明只有在验证记录确认对应行为后才可提交。以 App Store Connect 的实际提交详情状态报告审核进度，不能以 Archive、导出或上传成功代替「等待审核」。
