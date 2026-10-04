# SovietExtension 项目 Skill

## 入口

- 工程：`SovietExtension/SovietExtension.xcodeproj`
- 插件源码：`SovietExtension/SovietExtension/`
- 安装与版本清单：`SovietExtension/Rely/`
- 当前状态：`PROJECT_HANDOFF.md`

## 稳定约束

- 只支持逐 Build、逐架构验证过的微信二进制；版本号、Mach-O UUID 和补丁点指纹缺一不可。
- 新版本使用独立 profile，保留旧 profile，不覆盖或复用未经验证的旧地址。
- 对已知精确样本，安装器必须在修改 App 前同时匹配版本清单中的 `Resources/wechat.dylib` fat SHA-256 与 arm64 UUID；`--force` 只能放行未列出的版本，不能绕过已知 profile 门禁。
- 地址或 ABI 未确认的功能保持关闭，禁止猜测偏移、静默回退或仅放宽版本判断。
- 269079 与 270102 均使用独立的完整撤回链；SelfRevoke 升级必须同时核对栈布局、对象大小、字段偏移和所有跳转续点。
- 构建必须传 `SOVEXT_SKIP_INSTALL=1`，避免 Xcode Build Phase 修改 `/Applications/WeChat.app`。
- 主程序备份必须放在 `.app` 包外；旧式包内备份先校验并迁出，外置备份只能在最终签名验证成功后按需删除。
- 首次备份必须同目录临时复制、完整比较后原子改名；framework 名称、状态文件和备份路径必须先做 basename、文件类型和符号链接边界检查。
- 安装和卸载的失败路径优先恢复干净主程序并保留可验证备份；只有确认主程序无注入后才能删除 framework/state。恢复失败且主程序仍有加载项时必须保留依赖，不得报告成功。
- 安装和卸载都会对整个 App 执行 ad-hoc 重签；卸载不恢复厂商 Developer ID 签名或公证状态，只有从可信官方来源重装才能恢复。
- 自定义 `--app` 测试不得控制系统微信进程或重置其 TCC；arm64-only framework 在非 arm64 主机上必须 fail-closed。
- 未经明确授权，不安装插件、不启动账号验证、不提交、不推送、不发布。

## 适配顺序

1. 核对 `Info.plist` 的 short version/build、目标 `Resources/wechat.dylib` 架构、UUID 和 SHA-256。
2. 以旧版已验证函数为锚点，按规范化指令和调用关系定位新版入口。
3. 检查对象大小、字段偏移、函数签名和被覆盖指令；不能只迁移函数地址。
4. 新 profile 先做 UUID/入口指纹 fail-closed 校验，再启用对应功能。
5. 使用 `SOVEXT_SKIP_INSTALL=1` 构建；Xcode 27 需命令行覆盖 `MACOSX_DEPLOYMENT_TARGET=12.0`，再运行 `tools/verify_wechat_270102.py` 校验精确 fat/arm64 SHA、唯一切片、Mach-O UUID、全部 14 个适配源码文件整文件摘要、源码指纹清单和地址映射并做差异检查。适配源码有意修改后必须同步更新整文件摘要。
6. 在精确目标 App 的隔离副本上验证默认产物的安装、fat 主程序加载项、arm64 framework、深度签名、原子外置备份、重复安装、卸载、故障恢复和旧备份迁移；自定义 App 路径不得操作系统微信进程或 TCC。
7. 真实账号验证单独授权，并记录未验证边界和恢复方式。

## 发布与恢复

- 正式二进制必须来自项目构建流程，不手改 `Rely/Plugin` 内产物。
- 发布前同步 README、`supported_versions.txt`、`PROJECT_HANDOFF.md` 和构建产物。
- 发布前校验目标 App 原始签名和样本来源；若原始签名不可验证，只能声明适配精确 SHA/UUID 样本，不能称为已确认的官方原包。
- 安装测试前保存官方应用基线；恢复使用 `Rely/uninstall.sh` 或重装官方微信。
