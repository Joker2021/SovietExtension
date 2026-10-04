<p align="center">
  <img src="./3.1.png" width="900" alt="SovietExtension Banner" />
</p>

<h1 align="center">SovietExtension 苏维埃助手</h1>

<p align="center">
  For 开源共产主义，For 理想主义。<br/>
  免费的，抽象的，令人愉快的 Mac 微信插件。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-lightgrey.svg" />
  <img src="https://img.shields.io/badge/Apple%20Silicon-M%20Chip-brightgreen.svg" />
  <img src="https://img.shields.io/badge/WeChat-4.0%2B-07C160.svg" />
  <a href="LICENSE">
    <img src="https://img.shields.io/github/license/fstudio/clangbuilder.svg" />
  </a>
  <a href="https://996.icu">
    <img src="https://img.shields.io/badge/link-996.icu-red.svg" />
  </a>
</p>

---

## Effect / 效果展示
> 自定义**殺馬特**效果速度、大小、强度，殺馬特or高级感全凭各位自己手艺，我更喜欢殺馬特而已。

> 🔞→嗳丄了祢℡ωǒ…吥徻↘後悔∵╭→很嗳﹎∩ 答应 ↘永逺┈⊕┈与∩ì.在∟┅ ↑起❤️
<p align="center">
  <img src="./colorful1.gif" width="1000" alt="SovietExtension Effect 1" />
</p>

<p align="center">
  <img src="./1.8.png" width="1000" alt="SovietExtension Effect 1" />
</p>

<p align="center">
  <img src="./1.9.png" width="1000" alt="SovietExtension Effect 2" />
</p>

<p align="center">
  <img src="./2.2.png" width="1000" alt="SovietExtension Effect 3" />
</p>

<p align="center">
  <img src="./4.1.png" width="1000" alt="SovietExtension Effect 2" />
</p>

<p align="center">
  <img src="https://star-history.dera.page/svg?repos=MustangYM/SovietExtension&type=Date" width="600" alt="SovietExtension Effect 3" />
</p>

---

## Supported Version / 支持版本

> **睁大眼睛看：目前只支持下表列出的 Apple Silicon / M 芯片版本。**
> 本人没有 Intel 机器，无法开发和测试 Intel 版本，所以 Intel 版目前无效。
> 微信 4.x QT 化之后逆向起来比较麻烦，其他版本随缘适配。
> 代码已完全开源，可自行查看，爱你。

请注意：[微信官网](https://mac.weixin.qq.com/) 显示的大版本号可能一致，但实际小版本和 Build 号可能不同。
使用前请务必核对完整版本号和 Build 号。

| 微信版本      | Build 号 | Apple Silicon / M 芯片 | Intel | 下载地址                                                                        | 说明                       |
| --------- | ------: | :------------------: | :---: | --------------------------------------------------------------------------- | ------------------------ |
| 4.1.15 |  270102 |         🧪 交付候选         | ❌ 不支持 | 本地精确样本 | 私有 ABI、Release 产物及隔离副本安装/卸载链已验证；账号运行验证待完成 |
| 4.1.11.23 |  269079 |         ✅ 支持         | ❌ 不支持 | [Github 归档](https://github.com/zsbai/wechat-versions/releases/tag/4.1.11.23)           | [1.1.2](https://github.com/MustangYM/SovietExtension/releases/tag/1.1.2) 已测试 |
| 4.1.10.53 |  268853 |         ✅ 支持         | ❌ 不支持 | [微信官网](https://weixin.qq.com/updates?platform=mac&version=4.1.10)           | 截止 2026-06-19，我在官网下载到的版本 |

> “交付候选”表示已按表中精确 Build、UUID 和 SHA-256 样本重新定位并校验入口，也已验证构建、安装、ad-hoc 深度签名、卸载和恢复链；尚未使用真实账号运行验证，不承诺账号安全或完整功能。
> 不在表格中的版本暂不保证可用。
> 即使大版本看起来一样，只要 Build 号不同，也可能无法使用。

[wechat-versions历史版本下载](https://github.com/zsbai/wechat-versions/releases)

## Adaptation Branch / 适配分支记录

本节记录 `adapt/wechat-versions` 分支的适配情况；不会影响 `main` 分支。

- 上游基线：`MustangYM/SovietExtension` 1.4.3（`a0e7533`）
- 维护方式：每个微信 Build 使用独立 profile，保留已经支持的旧版本
- 安全策略：完整版本、Build、Mach-O UUID 或入口指纹不匹配时，对应功能保持关闭
- 详细技术交接：[PROJECT_HANDOFF.md](PROJECT_HANDOFF.md)

### 2026-10-04：微信 4.1.15 / Build 270102

| 项目 | 状态 |
| --- | --- |
| 架构 | Apple Silicon / arm64 |
| 适配状态 | 🧪 交付产物与隔离安装/卸载链验证完成，真实账号运行验证待完成 |
| 目标 UUID | `3B7B6ABB-2C36-3E58-A384-CDEF05A57AA5` |
| fat SHA-256 | `d89434bb90b65991aa35a32e6b48a5825b0b1906e7142b12387c32fd76996b94` |
| arm64 SHA-256 | `07e35c5d8ea0d97f1f16d79a5efec42fa1ca97213f634d473631beeaae8f0841` |
| 旧版本兼容 | 保留 4.1.10.53 / Build 268853 与 4.1.11.23 / Build 269079 的独立配置和原有行为 |

已完成的代码级适配：

- 他人撤回、本人撤回、重新编辑保留和过期处理
- 消息同步、消息菜单、媒体操作和转发给本人
- 退群监控、群成员昵称缓存、侧边栏、多开和系统浏览器
- 270102 使用独立对象布局、函数地址、跳转续点和入口指纹，不复用 269079 地址

已完成的验证：

- 本地 DMG 的版本、Build、Mach-O UUID、SHA-256 和 arm64 切片核对；DMG SHA-256 为 `d87de447a43cd2d59aef441d3a8b32aad255427289581afcffc90aee0735dfc2`
- `tools/verify_wechat_270102.py` 在普通模式和 `python -O` 下均通过：先校验精确 fat/arm64 SHA、唯一 arm64 切片、Mach-O UUID 和全部 14 个适配源码文件整文件摘要，再自动复核源码 101 个入口指纹、合计 119 个唯一二进制检查点和 51 个新旧地址映射
- 安装器在修改 App 前会按 `supported_versions.txt` 对 270102 的 `Resources/wechat.dylib` 执行精确 fat SHA-256 和 arm64 UUID 门禁；即使使用 `--force` 也不能绕过已知 profile 的精确校验
- 精确门禁负例已验证：目标 dylib 仅改动 1 字节时，普通模式和 `--force` 均在创建备份、framework 或状态文件前拒绝安装
- 校验器负例已覆盖任一适配源码文件摘要变化、源码表被注释或禁用、非 arm64 切片被修改、重复 arm64/arm64e、fat 越界/截断及异常 UUID load command，均会拒绝
- Xcode 27 Release `clean build` 与 `analyze` 退出码均为 0；仅保留原工程已有告警
- `Rely/Plugin/SovietExtension.framework` 已替换为本分支最新 clean build 的 Release 产物；arm64 UUID 为 `E62683BA-4B0E-35AA-9A6A-E01E00142D98`，二进制 SHA-256 为 `5d367c1d7020248e4f540e7da55a2ea683ff39da9f8c8b6a99f28428357a01cb`
- framework 保持 macOS 12.0 最低部署目标；侧边栏架构识别不再调用 macOS 13 才提供的 API，macOS 26 的辅助功能角色也增加了运行时可用性门禁
- 在该 DMG 的隔离副本上完成默认 `install.sh`、重复安装和 `uninstall.sh --remove-backup`：fat 主程序的 x86_64 与 arm64 切片各写入 1 条加载项；交付 framework 仅支持 arm64，不支持 Intel 或 Rosetta 运行；安装/卸载后的 ad-hoc 深度签名验证均通过，卸载后注入项、framework、状态和备份均清除
- 安装备份存放在 `.app` 包外的同级专用目录并以“临时文件复制 → 完整比较 → 原子改名”生成；复用和恢复前校验安全名称、文件类型、符号链接、注入状态与 Mach-O UUID，旧式包内备份先迁出
- 已故障注入验证：部分备份复制、安装/卸载签名、恢复复制失败均会停止并保持可恢复状态；无法恢复干净主程序时保留仍被注入程序依赖的 framework/state；只有最终签名验证成功后，`--remove-backup` 才删除备份
- 自定义 `--app` 隔离路径不会退出系统微信进程，也不会重置系统微信的 TCC 授权；危险 framework 名称、状态文件符号链接和越界备份路径会在修改前拒绝

样本来源边界：DMG 的 `WhereFroms` 元数据指向腾讯官方域名，且 DMG 容器校验和有效，但其中原始 `WeChat.app` 的内嵌代码签名在本机无法通过验证。因此本分支只声明适配上述精确 SHA/UUID 样本，不把它描述为已确认签名完整的官方原包。安装器和卸载器都会对整个 App 执行 ad-hoc 重签；卸载可恢复无注入主程序，但不会恢复腾讯 Developer ID 签名或公证状态。只有删除后从可信官方来源重新安装微信，才能恢复厂商签名。交付 framework 同样使用 ad-hoc 签名，无 TeamIdentifier，不是 Apple Developer 身份签名或公证产物。

尚未进行的验证：

- 本轮未安装或修改 `/Applications/WeChat.app`
- 未使用真实微信进程和账号测试，因此不承诺完整运行效果或账号安全
- 4.1.10.53 / Build 268853 与 4.1.11.23 / Build 269079 的 profile 和源码行为已保留，但本轮均未做真实运行回归

---

## Install / 安装

### 1. 先打开一次微信

如果是刚安装的微信，请先手动打开一次微信，然后再安装插件。

否则安装完成后，可能会提示：

```text
“xxx” 已损坏，无法打开。
```

### 2. 执行安装脚本

进入 `Rely` 文件夹，执行 `install.sh`：

```bash
cd SovietExtension/Rely
sh install.sh
```

或者在仓库根目录执行：

```bash
sh SovietExtension/Rely/install.sh
```

安装后打开微信，如出现权限提示，请按引导完成授权。

安装脚本会先核对支持表；270102 还会在修改 App 前精确校验 `Resources/wechat.dylib` 的 fat SHA-256 与 arm64 UUID，`--force` 也不能跳过这项门禁。原始主程序备份到 `/Applications/WeChat.app.SovietExtensionBackup/`，不会放进 App 包内。备份完整比较后才原子写入正式名称。安装失败会优先自动恢复并保留备份；若无法确认主程序已恢复干净，则保留现有 framework 和状态文件，避免让仍带加载项的主程序缺少依赖。卸载默认保留备份；只有恢复和最终 ad-hoc 深度签名校验均成功后，`uninstall.sh --remove-backup` 才会删除本次安装对应的备份。

安装和卸载都会对整个 `WeChat.app` 执行 ad-hoc 重签。卸载会恢复无插件加载项的主程序，但不会恢复腾讯 Developer ID 签名或 Apple 公证状态；需要恢复厂商签名时，请删除现有 App 后从可信官方来源重新安装微信。

安装过程示例：

```text
repo-root % sh SovietExtension/Rely/install.sh

==============================
 Install SovietExtension
==============================

APP_PATH=/Applications/WeChat.app
PLUGIN_SRC_PATH=<仓库目录>/SovietExtension/Rely/Plugin/SovietExtension.framework
FRAMEWORK_DST_PATH=/Applications/WeChat.app/Contents/MacOS/SovietExtension.framework
INSERT_DYLIB_PATH=<仓库目录>/SovietExtension/Rely/insert_dylib
SUPPORTED_FILE=<仓库目录>/SovietExtension/Rely/supported_versions.txt
LOAD_DYLIB_PATH=@executable_path/SovietExtension.framework/SovietExtension

👉 [INFO] Detected WeChat version / 检测到微信版本:
    CFBundleShortVersionString: 4.1.15
    CFBundleVersion:            270102

✅ [OK] Version supported / 版本检查通过
    Supported Display Version: 4.1.15
    Matched Rule:              4.1.15|4.1.15|270102|Exact SHA/UUID sample: artifact and isolated install/uninstall verified; runtime account test pending

👉 [INFO] Verify exact WeChat binary profile / 校验精确微信二进制样本...
✅ [OK] Exact binary profile verified / 精确二进制样本校验通过
    wechat.dylib SHA-256: d89434bb90b65991aa35a32e6b48a5825b0b1906e7142b12387c32fd76996b94
    arm64 UUID:           3B7B6ABB-2C36-3E58-A384-CDEF05A57AA5

...省略一万句...

👉 [INFO] Verify code signature / 检查签名...
✅ [OK] Ad-hoc deep signature verified / ad-hoc 深度签名验证通过

==============================
✅ SovietExtension installed successfully
✅ SovietExtension 安装完成
==============================

Run WeChat and watch log / 启动微信并查看日志：
  rm -f /tmp/YMWeChatAntiRevokePatch.log
  open -a WeChat
  tail -f /tmp/YMWeChatAntiRevokePatch.log

Uninstall / 卸载：
  <仓库目录>/SovietExtension/Rely/uninstall.sh
```

---

## Troubleshooting / 常见问题

### 1. 提示 `Operation not permitted`

如果安装时报错：

```text
cp: xxxxx: Operation not permitted
```

请到：

```text
系统设置 → 隐私与安全性
```

给你当前运行脚本的“终端工具”开启以下权限：

| 权限                          | 说明         |
| --------------------------- | ---------- |
| 完整磁盘访问权限 / Full Disk Access | 允许脚本修改应用目录 |
| 文件与文件夹 / Files and Folders  | 允许访问相关文件   |

常见终端工具包括：

* Terminal / 终端
* iTerm2
* VSCode
* Cursor
* Warp

你用哪个工具执行脚本，就给哪个工具开权限。

### 2. 如果反复弹窗提示[”微信“想访问其他App的数据]
```text
在系统设置中打开微信”完全磁盘访问“，如果微信已经在里面，则删除后重新添加。
```

---

### 3. 提示版本不支持

请确认你的微信版本和 Build 号是否在支持表格中。

查看方式：

```bash
defaults read /Applications/WeChat.app/Contents/Info.plist CFBundleShortVersionString
defaults read /Applications/WeChat.app/Contents/Info.plist CFBundleVersion
```

只有表格中明确列出的版本才保证可用。

---

### 4. 安装后微信打不开

可以先执行卸载脚本恢复：

```bash
sh SovietExtension/Rely/uninstall.sh
```

确认卸载成功后同时删除本次安装备份：

```bash
sh SovietExtension/Rely/uninstall.sh --remove-backup
```

如果仍然打不开，可以删除微信后重新安装官方版本。

---

## Uninstall / 卸载

进入 `Rely` 文件夹，执行：

```bash
sh uninstall.sh
```

或者在仓库根目录执行：

```bash
sh SovietExtension/Rely/uninstall.sh
```

卸载完成仅表示主程序已恢复为无插件加载项且 ad-hoc 深度签名验证通过，不代表腾讯原签名或公证状态已恢复；如需恢复厂商签名，请从可信官方来源重新安装微信。

---

## Notes / 说明

* 本项目仅用于学习、研究与个人折腾。
* 插件通过注入和私有 ABI 修改微信，可能违反平台规则，并存在崩溃、功能异常或账号限制风险；请勿用于重要账号或生产环境。
* 代码完全开源，可自行查看实现。
* 不接受除 Bug 以外的任何 Issue。
* 不接受任何形式的捐赠与收费。
* 其他版本适配随缘，别催，催就是你对。

---

## Thanks / 致谢

感谢湖畔大学全体同学。

**瑞思拜。**

MustangYM.

---

## License / 开源协议

<a href="LICENSE">
  <img src="https://img.shields.io/github/license/fstudio/clangbuilder.svg" />
</a>

<a href="https://996.icu">
  <img src="https://img.shields.io/badge/link-996.icu-red.svg" />
</a>
