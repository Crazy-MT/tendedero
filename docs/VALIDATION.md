# PegNest 验证记录

日期：2026-10-11。macOS 本机；Xcode 26.6 / Swift 6.3.3。

## 已完成

- `swift test`：21 项全部通过。覆盖完整文字与 UTF-8 上限、PNG/TIFF、私密/文件/多项目过滤、异步过期回调、私有副本和索引恢复、重复内容、复制标记、容量与适应屏幕重启、导出、原文件保护、存储失败、授权撤销与失效书签保留。
- `swift scripts/check-strings.swift`：79 个当前字符串；发行包仅带英文与简体中文。
- Universal Release 本机沙盒构建，Apple silicon 与 Intel；发布结构脚本核查图标、许可证、隐私清单、沙盒权限与私有符号。
- 原始 LICENSE 与应用内 LICENSE 副本一致；移除上游排除授权的名称品牌、图标和文档宣传图片，保留来源声明。
- 实际桌面验证首次控制窗口和开启记录的告知弹窗。用户已开启系统剪贴板记录。2026-10-11 修复私有目录路径别名识别及缺失索引恢复；通过 TextEdit 复制合成文本，历史计数由 5 增至 7，Release 重启后挂绳 AX 树包含两段合成文本卡片。原有未索引副本已恢复，未清空用户历史。
- Apple Developer 已注册 本应用正式 Bundle ID；用户确认创建两张 Mac App Store 分发证书后，应用与安装包签名身份均已验证。专属描述文件已安装，最新代码的 Apple Development 签名 Archive 与手动签名 App Store Export 成功。`pkgutil --check-signature` 确认安装包由 Apple 签发的 Mac Installer Distribution 签名；Archive 严格 codesign 校验通过。Xcode 仍报告旧账号 Token 缺失，手动导出已成功，此前旧账号警告未阻止本次 Transporter 成功交付。
- App Store Connect 已创建「晾贴」macOS 记录，刷新后确认状态为「准备提交」。用户接受 Transporter 许可后，1.0.0（1）已交付并处理完成；App Store Connect 已选择该构建并保存加密问卷。2026-10-11 19:06 已提交；审核详情确认“等待审核”，构建 1.0.0（1）。

## 仍需完成

- 多显示器、全屏、拖出、Quick Look、外部图片编辑、录屏裁剪、登录启动尚未重新逐项验收。
- 支持邮箱沿用真实既有公开地址，未重新验证收信。

自动化测试使用临时目录与具名测试剪贴板，不代表系统剪贴板或桌面行为已经验收。本机临时签名构建不代表商店签名；商店签名、交付与提交由上述独立证据确认。

- 用户指定 Notion 托管后，两份应用专属页面公开发布成功；独立 IAB 页面无需登录即可看到支持说明与完整隐私政策。中英文 App Store Connect 技术支持 URL、隐私政策 URL 已保存为这些 Notion 地址。

- 使用独立 `local.PegNest.StoreQA` 沙盒身份运行最新 Archive 二进制：TextEdit 实际复制三段合成文字，暂停后新复制不增加历史；系统 NSOpenPanel 授权测试目录后新图片自动成为第四张卡片，重启后四张恢复。卡片点击显示“已复制”，粘贴回 TextEdit 与原文一致；双击文字显示完整换行。
- 商店截图使用真实测试界面及合成内容。仅截图用临时 harness 固定挂绳显示并避免自动化激活时弹出控制窗口，未修改卡片渲染；该 harness 未进入商店包，截图后已终止并恢复 QA 应用为 Archive 二进制。
- 中文和英文各三张 2880×1800 商店截图已上传。免费无内购已由用户确认并保存；Notion 两个 URL、中英文元数据、真实审核联系方式、4+ 年龄评级和未收集数据声明均已保存。

- 最终审核详情：macOS App 1.0，构建 1.0.0（1），等待审核；本机证明截图 `build/store-waiting-review.png`。审核通过后自动发布。
