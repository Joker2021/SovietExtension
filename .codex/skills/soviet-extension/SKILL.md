# SovietExtension 项目 Skill

## 入口

- 工程：`SovietExtension/SovietExtension.xcodeproj`
- 插件源码：`SovietExtension/SovietExtension/`
- 安装与版本清单：`SovietExtension/Rely/`
- 当前状态：`PROJECT_HANDOFF.md`

## 稳定约束

- 只支持逐 Build、逐架构验证过的微信二进制；版本号、Mach-O UUID 和补丁点指纹缺一不可。
- 新版本使用独立 profile，保留旧 profile，不覆盖或复用未经验证的旧地址。
- 地址或 ABI 未确认的功能保持关闭，禁止猜测偏移、静默回退或仅放宽版本判断。
- 269079 与 270102 均使用独立的完整撤回链；SelfRevoke 升级必须同时核对栈布局、对象大小、字段偏移和所有跳转续点。
- 构建必须传 `SOVEXT_SKIP_INSTALL=1`，避免 Xcode Build Phase 修改 `/Applications/WeChat.app`。
- 未经明确授权，不安装插件、不启动账号验证、不提交、不推送、不发布。

## 适配顺序

1. 核对 `Info.plist` 的 short version/build、目标 `Resources/wechat.dylib` 架构、UUID 和 SHA-256。
2. 以旧版已验证函数为锚点，按规范化指令和调用关系定位新版入口。
3. 检查对象大小、字段偏移、函数签名和被覆盖指令；不能只迁移函数地址。
4. 新 profile 先做 UUID/入口指纹 fail-closed 校验，再启用对应功能。
5. 使用 `SOVEXT_SKIP_INSTALL=1` 构建；Xcode 27 需命令行覆盖 `MACOSX_DEPLOYMENT_TARGET=12.0`，再运行 `tools/verify_wechat_270102.py` 校验完整地址/指纹清单并做差异检查。
6. 真实账号验证单独授权，并记录未验证边界和恢复方式。

## 发布与恢复

- 正式二进制必须来自项目构建流程，不手改 `Rely/Plugin` 内产物。
- 发布前同步 README、`supported_versions.txt`、`PROJECT_HANDOFF.md` 和构建产物。
- 安装测试前保存官方应用基线；恢复使用 `Rely/uninstall.sh` 或重装官方微信。
