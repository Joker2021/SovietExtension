# SovietExtension 维护交接

## 项目目标与边界

- 为 Apple Silicon Mac 微信提供 SovietExtension 插件。
- 私有 ABI 必须按完整微信 Build 和 `Resources/wechat.dylib` UUID 分版本适配；不得把旧地址直接放行到新版本。
- 不在维护过程中自动安装到 `/Applications/WeChat.app`，构建时必须设置 `SOVEXT_SKIP_INSTALL=1`。

## 当前分支与版本

- 分支：`adapt/wechat-versions`
- 基线：`a0e7533`（上游 1.4.3）
- 目标微信：4.1.15 / Build 270102 / arm64
- 目标 `wechat.dylib` UUID：`3B7B6ABB-2C36-3E58-A384-CDEF05A57AA5`
- 目标 arm64 SHA-256：`07e35c5d8ea0d97f1f16d79a5efec42fa1ca97213f634d473631beeaae8f0841`
- 发布状态：适配分支已提交并推送至 `origin`；未创建标签或 Release，未替换 `Rely/Plugin` 正式产物。

## 当前状态

- 保留原 4.1.11.23 / 269079 配置和行为。
- 新增 270102 独立 profile，MessageWrap 大小更新为 632 字节。
- 已静态适配他人/本人防撤回、撤回重新编辑保留与过期处理、消息同步、消息菜单和媒体操作、转发、退群监控与昵称缓存、侧边栏、多开和系统浏览器等私有 ABI。
- 270102 不复用 269079 地址；UUID 或任一入口指纹不符时对应功能 fail-closed。

## 验证边界与风险

- 已完成：官方 DMG 的版本、UUID、入口指令和 arm64 切片静态核对。
- 已完成：Xcode 27 无缓存 Release `clean build` 和 `analyze`（`SOVEXT_SKIP_INSTALL=1`，命令行覆盖 `MACOSX_DEPLOYMENT_TARGET=12.0`）；均以退出码 0 完成，仅有原工程已有告警。产物为 arm64，SHA-256 为 `94a282fc3a9043b8f5c2b3205de909e05db711ae781e325cf7a9394e0ba693d7`。
- 已完成：`tools/verify_wechat_270102.py` 同时通过只读 DMG 内官方 fat dylib 和抽取后的 arm64 切片；源码中 SelfRevoke、消息菜单、媒体和侧边栏共 101 个 270102 指纹逐项与官方二进制一致，51 个新旧地址映射无遗漏。
- 未进行：未替换仓库 `Rely/Plugin` 的既有正式 framework，也未安装到 `/Applications/WeChat.app`。
- 未完成：真实微信进程和账号运行验证；不得描述为已实测。
- 插件注入和私有 ABI 修改可能违反平台规则并带来稳定性或账号限制风险，不能承诺不会封号。

## 常用检查

```bash
git status --short --branch
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SOVEXT_SKIP_INSTALL=1 xcodebuild -project SovietExtension/SovietExtension.xcodeproj -scheme SovietExtension -configuration Release CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build
python3 tools/verify_wechat_270102.py /path/to/WeChat.app/Contents/Resources/wechat.dylib
```

## 恢复

- 源码恢复：切回 `main`；不要重写或删除原 269079 profile。
- 应用恢复：若以后人工安装测试，使用 `SovietExtension/Rely/uninstall.sh`，或重装官方微信。

## 项目 Skill

- `.codex/skills/soviet-extension/SKILL.md`

## 新会话提示

先核对当前分支、DMG 的 Build/UUID/hash 和工作区状态；270102 已完成代码级静态适配，下一阶段是经单独授权的本地运行验证。不要把“静态适配”当作账号实测。
