# PegNest 验证记录

日期：2026-10-11。macOS 本机；Xcode 26.6 / Swift 6.3.3。

## 已完成

- `swift test`：19 项全部通过。覆盖完整文字与 UTF-8 上限、PNG/TIFF、私密/文件/多项目过滤、异步过期回调、私有副本和索引恢复、重复内容、复制标记、容量与适应屏幕重启、导出、原文件保护、存储失败、授权撤销与失效书签保留。
- `swift scripts/check-strings.swift`：79 个当前字符串；发行包仅带英文与简体中文。
- Universal Release 本机沙盒构建，Apple silicon 与 Intel；发布结构脚本核查图标、许可证、隐私清单、沙盒权限与私有符号。
- 原始 LICENSE 与应用内 LICENSE 副本一致；移除上游排除授权的名称品牌、图标和文档宣传图片，保留来源声明。
- 实际桌面验证首次控制窗口和开启记录的告知弹窗。尚未批准开启系统剪贴板记录，未读取已有剪贴板内容。
- Apple Developer 页面已注册 `<registered-bundle-id>`；Apple Development 签名 Archive 成功。商店导出失败：缺少该 ID 的分发描述文件；Apple Developer 的 Mac App Store profile 页面确认没有可选分发证书。创建签名私钥/证书等待用户确认，Xcode 自动签名账号凭据也需要刷新。

## 仍需完成

- 真实系统剪贴板：启用、纯合成内容复制、卡片回拷、暂停、重启；完成后暂停。
- NSOpenPanel 的真实沙盒书签、目录新文件、跨重启恢复；多显示器、全屏、拖出、Quick Look、外部图片编辑、录屏裁剪、登录启动。
- 商店 Archive/Export/上传与 App Store Connect 的实际审核状态；以最终日志和页面更新本记录。
- 真实支持邮箱、版权主体、定价、公开支持/隐私 URL、商店截图与最终资料。

自动化测试使用临时目录与具名测试剪贴板，不代表系统剪贴板或桌面行为已经验收。本机临时签名构建也不代表商店签名或已经提交。
