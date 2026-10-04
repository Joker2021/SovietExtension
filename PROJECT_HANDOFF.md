# SovietExtension 维护交接

## 项目目标与边界

- 为 Apple Silicon Mac 微信提供 SovietExtension 插件。
- 私有 ABI 必须按完整微信 Build 和 `Resources/wechat.dylib` UUID 分版本适配；不得把旧地址直接放行到新版本。
- 不在维护过程中自动安装到 `/Applications/WeChat.app`，构建时必须设置 `SOVEXT_SKIP_INSTALL=1`。

## 当前分支与版本

- 分支：`adapt/wechat-versions`
- 基线：`a0e7533`（上游 1.4.3）
- 目标微信：4.1.15 / Build 270102 / arm64
- 目标 DMG SHA-256：`d87de447a43cd2d59aef441d3a8b32aad255427289581afcffc90aee0735dfc2`
- 目标 `wechat.dylib` UUID：`3B7B6ABB-2C36-3E58-A384-CDEF05A57AA5`
- 目标 fat SHA-256：`d89434bb90b65991aa35a32e6b48a5825b0b1906e7142b12387c32fd76996b94`
- 目标 arm64 SHA-256：`07e35c5d8ea0d97f1f16d79a5efec42fa1ca97213f634d473631beeaae8f0841`
- 发布状态：适配与交付变更均位于 `adapt/wechat-versions` 并推送至 `origin`；未创建标签或 Release。

## 当前状态

- 保留原 4.1.10.53 / 268853 与 4.1.11.23 / 269079 配置和行为。
- 新增 270102 独立 profile，MessageWrap 大小更新为 632 字节。
- 已静态适配他人/本人防撤回、撤回重新编辑保留与过期处理、消息同步、消息菜单和媒体操作、转发、退群监控与昵称缓存、侧边栏、多开和系统浏览器等私有 ABI。
- 270102 不复用 269079 地址；UUID 或任一入口指纹不符时对应功能 fail-closed。
- `Rely/Plugin/SovietExtension.framework` 已替换为当前分支的 Release 产物。
- 安装器在修改 App 前按版本清单执行精确二进制门禁；当前 270102 规则强制匹配 `Resources/wechat.dylib` 的 fat SHA-256 和 arm64 UUID，`--force` 不会绕过。
- 安装器把主程序备份放在 `.app` 外的同级 `${APP_PATH}.SovietExtensionBackup` 目录；首次备份经临时文件完整比较后原子改名，恢复前校验安全名称、文件类型、符号链接、注入状态和 Mach-O UUID，旧式包内备份先迁出。
- 安装/卸载中途失败会尝试恢复到无注入且 ad-hoc 深度签名可验证的状态并保留外置备份；若无法证明主程序已恢复干净，则保留仍被加载项依赖的 framework/state；`--remove-backup` 只在最终 ad-hoc 深度签名验证成功后删除备份。
- 自定义 `--app` 路径不操作系统微信进程、不重置系统微信 TCC；当前交付 framework 为 arm64-only，Intel/Rosetta fail-closed。

## 关键目录与职责

- `SovietExtension/SovietExtension/`：插件源码和逐 Build 私有 ABI profile。
- `SovietExtension/Rely/`：支持版本表、安装/卸载脚本、注入工具和默认交付 framework。
- `tools/verify_wechat_270102.py`：270102 精确 fat/arm64 样本、全部 14 个适配源码文件整文件摘要、源码指纹清单和地址映射的可运行校验。
- `.codex/skills/soviet-extension/`：Agent 维护边界、适配顺序和发布恢复规则。

## 验证边界与风险

- 已完成：本地 DMG 的版本、UUID、入口指令和 arm64 切片静态核对；`WhereFroms` 元数据指向腾讯官方域名，DMG 容器校验和有效。
- 已完成：Xcode 27 无缓存 Release `clean build` 和 `analyze`（`SOVEXT_SKIP_INSTALL=1`，命令行覆盖 `MACOSX_DEPLOYMENT_TARGET=12.0`）；均以退出码 0 完成。复核中修复了侧边栏对 macOS 13 架构命名 API 和 macOS 26 辅助功能角色的无保护调用；剩余为原工程的弃用、声明顺序、未使用函数、模块图及低层 ABI 静态分析告警。仓库内最终签名产物为 arm64，UUID 为 `E62683BA-4B0E-35AA-9A6A-E01E00142D98`，二进制 SHA-256 为 `5d367c1d7020248e4f540e7da55a2ea683ff39da9f8c8b6a99f28428357a01cb`，与本轮构建输出的 binary、Info.plist、CodeResources 一致。
- 已完成：`tools/verify_wechat_270102.py` 在普通模式和 `python -O` 下通过；先门禁精确 fat/arm64、唯一 arm64 切片、Mach-O UUID 和全部 14 个适配源码文件摘要，再复核 101 个源码入口指纹、119 个唯一二进制检查点和 51 个新旧地址映射。任一适配源码摘要变化、源码禁用、非 arm64 切片篡改和畸形 fat/Mach-O 负例均拒绝。
- 已完成：安装器的 270102 精确门禁正例、重复安装和卸载通过；`wechat.dylib` 改动 1 字节后，普通模式及 `--force` 均在创建备份、framework 或状态文件前拒绝。随后仅将被改动的 `Resources/wechat.dylib` 恢复为精确目标 SHA；测试副本保持无注入且 ad-hoc 深度签名验证通过。
- 已完成：在该 4.1.15 / 270102 DMG 的隔离副本上运行仓库默认安装产物及重复安装；fat 主程序的 x86_64 与 arm64 各写入 1 条 `LC_LOAD_DYLIB`，外置备份 SHA-256 与安装前主程序一致，安装后 ad-hoc 深度签名验证通过。framework 仅为 arm64，未声明 Intel/Rosetta 支持。
- 已完成：同一隔离副本运行 `uninstall.sh --remove-backup`；注入项、framework、状态文件和备份目录均清除，卸载后的 ad-hoc 深度签名验证通过。
- 已完成：模拟部分备份复制、安装/卸载阶段 `codesign` 失败以及恢复复制失败；正常恢复后无注入项、无残留 framework/state、App ad-hoc 深度签名验证通过且备份保留，无法恢复干净主程序时会保留其 framework/state，随后正常卸载可恢复。路径穿越、状态符号链接、恶意状态备份路径均在修改前拒绝，旧式包内备份可安全迁出。
- 本轮未进行：未安装或修改 `/Applications/WeChat.app`，未启动隔离副本。
- 未完成：真实微信进程和账号运行验证；不得描述为已实测。
- 未完成：4.1.10.53 / Build 268853 与 4.1.11.23 / Build 269079 的真实运行回归；仅确认其独立 profile 与源码仍保留。
- 样本边界：DMG 内原始 `WeChat.app` 的内嵌代码签名无法通过本机验证；适配结论仅绑定上述精确 DMG SHA、arm64 SHA 和 UUID，不能表述为已确认签名完整的官方原包。
- 安装器和卸载器都会对整个 App 执行 ad-hoc 重签；卸载只恢复无注入主程序，不恢复腾讯 Developer ID 签名或公证状态，恢复厂商签名必须从可信官方来源重新安装微信。
- 交付 framework 为 ad-hoc 签名，无 TeamIdentifier，不是 Apple Developer 身份签名或公证产物。
- 插件注入和私有 ABI 修改可能违反平台规则并带来稳定性或账号限制风险，不能承诺不会封号。
- 本轮审计临时目录和帮助输出已按用户确认删除，只读 DMG 已卸载；原始 DMG 文件仍保留在下载目录。

## 常用检查

```bash
git status --short --branch
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SOVEXT_SKIP_INSTALL=1 xcodebuild -project SovietExtension/SovietExtension.xcodeproj -scheme SovietExtension -configuration Release CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build
python3 tools/verify_wechat_270102.py /path/to/WeChat.app/Contents/Resources/wechat.dylib
codesign --verify --deep --strict --verbose=2 SovietExtension/Rely/Plugin/SovietExtension.framework
shasum -a 256 SovietExtension/Rely/Plugin/SovietExtension.framework/SovietExtension
```

## 恢复

- 源码恢复：切回 `main`；不要重写或删除原 269079 profile。
- 应用恢复：人工安装后使用 `SovietExtension/Rely/uninstall.sh` 恢复无注入主程序；确认恢复完成后可加 `--remove-backup` 删除外置备份。卸载不会恢复厂商签名，需恢复腾讯 Developer ID 签名或公证状态时，从可信官方来源重新安装微信。

## 项目 Skill

- `.codex/skills/soviet-extension/SKILL.md`

## 新会话提示

先核对当前分支、DMG 的 Build/UUID/hash、样本签名边界和工作区状态；270102 的代码、交付 framework、故障恢复及隔离安装/卸载链均已验证，交付变更已推送至 `origin/adapt/wechat-versions`。下一阶段只能在单独授权后做真实进程和账号验证，不得把隔离验证描述为账号实测。
