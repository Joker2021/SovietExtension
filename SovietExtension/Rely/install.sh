#!/bin/bash

# 如果用户用 sh install.sh 执行，自动切换到 bash
# If user runs this script with sh, re-exec with bash.
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

set -euo pipefail

# ==============================
# SovietExtension installer
# ==============================

APP_NAME="WeChat"
FRAMEWORK_NAME="${FRAMEWORK_NAME:-SovietExtension}"
APP_PATH="/Applications/${APP_NAME}.app"
STANDARD_APP_PATH="/Applications/${APP_NAME}.app"
IS_SYSTEM_APP=0
FORCE=0
WRITE_INSTALL_STATE=1
RUN_SUDO=0
PLUGIN_SRC_PATH=""

# Runtime vars
APP_SHORT_VERSION=""
APP_BUILD_VERSION=""
MATCHED_DISPLAY_VERSION=""
MATCHED_LINE=""
MATCHED_FAT_SHA256=""
MATCHED_ARM64_UUID=""
BACKUP_PATH=""
BACKUP_DIR=""
HOST_ARCH=""
INSERT_DYLIB_PATH=""
INSERT_DYLIB_RUNNER=""
INSERT_DYLIB_RUN_MODE=""
INSTALL_ROLLBACK_READY=0
INSTALL_COMPLETED=0

# ------------------------------
# log helpers
# ------------------------------

die() {
    echo ""
    echo "❌ [ERROR] $*" >&2
    echo ""
    exit 1
}

warn() {
    echo "⚠️  [WARN] $*"
}

ok() {
    echo "✅ [OK] $*"
}

info() {
    echo "👉 [INFO] $*"
}

usage() {
    cat <<EOF_USAGE
Usage:
  ./install.sh
  sh install.sh
  ./install.sh --force
  ./install.sh --app=/Applications/WeChat.app

Options:
  --force              Allow an unlisted version; exact known-profile checks still apply / 允许未列出的版本；已知 profile 的精确校验仍会执行
  --no-install-state   Skip writing install state / 不写安装记录
  --app=PATH           Specify WeChat.app path / 指定 WeChat.app 路径
  --framework=NAME     Specify framework name, default: SovietExtension / 指定插件名，默认 SovietExtension
  --plugin=PATH        Install this built framework / 指定实际构建的 framework
  --insert-dylib=PATH  Specify insert_dylib path / 指定 insert_dylib 路径
  -h, --help           Show help / 显示帮助

Supported tool layout / 推荐工具文件布局：
  Rely/insert_dylib                  universal, best / universal 版，最推荐
  Rely/insert_dylib_arm64            Apple Silicon 专用
  Rely/insert_dylib_x86_64           Intel 专用
  Rely/insert-dylib                  Rust rewrite 版也可，脚本会尝试识别

EOF_USAGE
}

run_cmd() {
    if [ "${RUN_SUDO}" -eq 1 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE=1
            ;;
        --no-install-state)
            WRITE_INSTALL_STATE=0
            ;;
        --app=*)
            APP_PATH="${arg#--app=}"
            ;;
        --framework=*)
            FRAMEWORK_NAME="${arg#--framework=}"
            ;;
        --plugin=*)
            PLUGIN_SRC_PATH="${arg#--plugin=}"
            ;;
        --insert-dylib=*)
            INSERT_DYLIB_PATH="${arg#--insert-dylib=}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown argument / 未知参数: ${arg}"
            ;;
    esac
done

if [[ ! "${FRAMEWORK_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    die "Invalid framework name / 插件名只能包含字母、数字、下划线和连字符，且必须以字母或数字开头: ${FRAMEWORK_NAME}"
fi

APP_PATH="${APP_PATH%/}"
[ -n "${APP_PATH}" ] || die "App path must not be empty / App 路径不能为空"
if [ -d "${APP_PATH}" ]; then
    APP_PATH="$(cd "${APP_PATH}" && pwd -P)" || die "Cannot resolve App path / 无法解析 App 物理路径: ${APP_PATH}"
fi
if [ -d "${STANDARD_APP_PATH}" ]; then
    STANDARD_APP_PATH="$(cd "${STANDARD_APP_PATH}" && pwd -P)" || die "Cannot resolve system WeChat path / 无法解析系统微信物理路径"
fi
if [ "${APP_PATH}" = "${STANDARD_APP_PATH}" ]; then
    IS_SYSTEM_APP=1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MACOS_PATH="${APP_PATH}/Contents/MacOS"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"
APP_EXECUTABLE_PATH="${MACOS_PATH}/${APP_NAME}"
BACKUP_DIR="${APP_PATH}.${FRAMEWORK_NAME}Backup"

PLUGIN_SRC_PATH="${PLUGIN_SRC_PATH:-${SCRIPT_DIR}/Plugin/${FRAMEWORK_NAME}.framework}"
PLUGIN_SRC_BINARY_PATH="${PLUGIN_SRC_PATH}/${FRAMEWORK_NAME}"
FRAMEWORK_DST_PATH="${MACOS_PATH}/${FRAMEWORK_NAME}.framework"
FRAMEWORK_DST_BINARY_PATH="${FRAMEWORK_DST_PATH}/${FRAMEWORK_NAME}"

SUPPORTED_FILE="${SCRIPT_DIR}/supported_versions.txt"
LOAD_DYLIB_PATH="@executable_path/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}"
STATE_FILE="${MACOS_PATH}/.${FRAMEWORK_NAME}.install_state"
LOG_PATH="/tmp/YMWeChatAntiRevokePatch.log"

# ------------------------------
# utilities
# ------------------------------

read_plist() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :${key}" "${INFO_PLIST}" 2>/dev/null || true
}

trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

is_build_token() {
    local value="$1"

    if [ "${value}" = "*" ]; then
        return 0
    fi

    if [[ "${value}" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    return 1
}

command_required() {
    local cmd="$1"
    command -v "${cmd}" >/dev/null 2>&1 || die "Command not found / 命令不存在: ${cmd}"
}

check_required_commands() {
    info "Check required commands / 检查必要命令..."

    command_required /usr/libexec/PlistBuddy
    command_required cp
    command_required cmp
    command_required mkdir
    command_required mktemp
    command_required mv
    command_required rm
    command_required chmod
    command_required ditto
    command_required xattr
    command_required otool
    command_required codesign
    command_required file
    command_required grep
    command_required sed
    command_required awk
    command_required uname
    command_required pkill
    command_required pgrep
    command_required osascript

    if ! command -v lipo >/dev/null 2>&1; then
        warn "lipo not found. Architecture diagnosis will use file only / 未找到 lipo，将使用 file 做架构诊断"
    fi

    ok "Required commands exist / 必要命令存在"
}

get_archs() {
    local binary_path="$1"
    local info=""
    local archs=""

    if [ ! -f "${binary_path}" ]; then
        echo ""
        return 0
    fi

    if command -v lipo >/dev/null 2>&1; then
        info="$(lipo -info "${binary_path}" 2>/dev/null || true)"

        if echo "${info}" | grep -q "are:"; then
            archs="$(echo "${info}" | sed 's/^.*are:[[:space:]]*//')"
        fi

        if [ -z "${archs}" ] && echo "${info}" | grep -q "architecture:"; then
            archs="$(echo "${info}" | sed 's/^.*architecture:[[:space:]]*//')"
        fi
    fi

    if [ -z "${archs}" ]; then
        info="$(file "${binary_path}" 2>/dev/null || true)"

        echo "${info}" | grep -qw "x86_64" && archs="${archs} x86_64"
        echo "${info}" | grep -qw "arm64" && archs="${archs} arm64"
        echo "${info}" | grep -qw "arm64e" && archs="${archs} arm64e"
    fi

    echo "${archs}" | xargs 2>/dev/null || true
}

arch_matches() {
    local actual_arch="$1"
    local wanted_arch="$2"

    if [ "${actual_arch}" = "${wanted_arch}" ]; then
        return 0
    fi

    # arm64e 可以视作 Apple Silicon 系列，避免误判
    if [ "${wanted_arch}" = "arm64" ] && [ "${actual_arch}" = "arm64e" ]; then
        return 0
    fi

    return 1
}

binary_contains_arch() {
    local binary_path="$1"
    local wanted_arch="$2"
    local archs=""
    local arch=""

    archs="$(get_archs "${binary_path}")"

    for arch in ${archs}; do
        if arch_matches "${arch}" "${wanted_arch}"; then
            return 0
        fi
    done

    return 1
}

print_binary_info() {
    local title="$1"
    local path="$2"

    echo "    ${title}:"
    echo "      Path:  ${path}"
    echo "      Archs: $(get_archs "${path}")"
    echo "      File:  $(file "${path}" 2>/dev/null || true)"

    if command -v lipo >/dev/null 2>&1; then
        echo "      Lipo:  $(lipo -info "${path}" 2>/dev/null || true)"
    fi
}

is_rosetta_available() {
    if [ "$(uname -m)" != "arm64" ]; then
        return 1
    fi

    /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1
}

# ------------------------------
# file checks
# ------------------------------

check_basic_files() {
    info "Check files / 检查文件..."

    [ -d "${APP_PATH}" ] || die "WeChat.app not found / 找不到 WeChat.app: ${APP_PATH}"
    [ -f "${INFO_PLIST}" ] || die "Info.plist not found / 找不到 Info.plist: ${INFO_PLIST}"
    [ -f "${APP_EXECUTABLE_PATH}" ] || die "WeChat executable not found / 找不到微信主可执行文件: ${APP_EXECUTABLE_PATH}"

    [ -d "${PLUGIN_SRC_PATH}" ] || die "Plugin framework not found / 找不到插件 framework: ${PLUGIN_SRC_PATH}"
    [ -f "${PLUGIN_SRC_BINARY_PATH}" ] || die "Framework binary not found / framework 内找不到同名二进制: ${PLUGIN_SRC_BINARY_PATH}"

    [ -f "${SUPPORTED_FILE}" ] || die "supported_versions.txt not found / 找不到版本控制文件: ${SUPPORTED_FILE}"

    [ ! -L "${BACKUP_DIR}" ] || die "Backup directory must not be a symbolic link / 备份目录不能是符号链接: ${BACKUP_DIR}"
    if [ -e "${BACKUP_DIR}" ] && [ ! -d "${BACKUP_DIR}" ]; then
        die "Backup directory path is not a directory / 备份目录路径不是目录: ${BACKUP_DIR}"
    fi
    [ ! -L "${STATE_FILE}" ] || die "Install state must not be a symbolic link / 安装状态文件不能是符号链接: ${STATE_FILE}"
    if [ -e "${STATE_FILE}" ] && [ ! -f "${STATE_FILE}" ]; then
        die "Install state path is not a regular file / 安装状态路径不是普通文件: ${STATE_FILE}"
    fi

    # Resolve symlinks before copy_framework can remove the destination.
    local source_dir destination_dir
    source_dir="$(cd "${PLUGIN_SRC_PATH}" && pwd -P)"
    destination_dir="$(cd "${MACOS_PATH}" && pwd -P)/${FRAMEWORK_NAME}.framework"
    if [ -d "${FRAMEWORK_DST_PATH}" ]; then
        destination_dir="$(cd "${FRAMEWORK_DST_PATH}" && pwd -P)"
    fi
    case "${source_dir}/" in
        "${destination_dir}/"*) die "Plugin source overlaps destination / 插件源不能位于安装目标内" ;;
    esac

    ok "Files look good / 文件检查通过"
}

select_insert_dylib() {
    HOST_ARCH="$(uname -m)"

    local explicit_path="${INSERT_DYLIB_PATH:-}"
    local candidates=()
    local candidate=""

    info "Select insert_dylib tool / 选择 insert_dylib 工具..."

    if [ -n "${explicit_path}" ]; then
        candidates+=("${explicit_path}")
    fi

    # 优先选择当前架构专用工具，其次 universal/默认工具，最后兼容 Rust 重写版 insert-dylib
    candidates+=("${SCRIPT_DIR}/insert_dylib_${HOST_ARCH}")

    if [ "${HOST_ARCH}" = "arm64" ]; then
        candidates+=("${SCRIPT_DIR}/insert_dylib_arm64")
    elif [ "${HOST_ARCH}" = "x86_64" ]; then
        candidates+=("${SCRIPT_DIR}/insert_dylib_x86_64")
    fi

    candidates+=("${SCRIPT_DIR}/insert_dylib")
    candidates+=("${SCRIPT_DIR}/insert-dylib")

    INSERT_DYLIB_PATH=""
    INSERT_DYLIB_RUNNER=""
    INSERT_DYLIB_RUN_MODE="native"

    for candidate in "${candidates[@]}"; do
        [ -f "${candidate}" ] || continue

        chmod +x "${candidate}" >/dev/null 2>&1 || true
        xattr -rd com.apple.quarantine "${candidate}" >/dev/null 2>&1 || true

        if binary_contains_arch "${candidate}" "${HOST_ARCH}"; then
            INSERT_DYLIB_PATH="${candidate}"
            INSERT_DYLIB_RUNNER=""
            INSERT_DYLIB_RUN_MODE="native"
            break
        fi

        if [ "${HOST_ARCH}" = "arm64" ] && binary_contains_arch "${candidate}" "x86_64" && is_rosetta_available; then
            INSERT_DYLIB_PATH="${candidate}"
            INSERT_DYLIB_RUNNER="/usr/bin/arch -x86_64"
            INSERT_DYLIB_RUN_MODE="rosetta-x86_64"
            break
        fi
    done

    if [ -z "${INSERT_DYLIB_PATH}" ]; then
        echo ""
        warn "No compatible insert_dylib was found / 没有找到兼容当前机器的 insert_dylib"
        echo "    Host Arch: ${HOST_ARCH}"
        echo ""
        echo "    Checked paths / 已检查路径："

        for candidate in "${candidates[@]}"; do
            echo "      - ${candidate}"
            if [ -f "${candidate}" ]; then
                print_binary_info "candidate" "${candidate}"
            fi
        done

        echo ""
        die "Please provide universal insert_dylib, or put insert_dylib_${HOST_ARCH} in Rely/. / 请提供 universal 版 insert_dylib，或在 Rely/ 下放入 insert_dylib_${HOST_ARCH}"
    fi

    ok "insert_dylib selected / 已选择 insert_dylib"
    echo "    Path:     ${INSERT_DYLIB_PATH}"
    echo "    Run Mode: ${INSERT_DYLIB_RUN_MODE}"
    print_binary_info "insert_dylib" "${INSERT_DYLIB_PATH}"
    echo ""
}

check_arch_compatibility() {
    HOST_ARCH="$(uname -m)"

    info "Check architecture compatibility / 检查架构兼容性..."
    echo "    Host Arch / 当前机器架构: ${HOST_ARCH}"
    print_binary_info "WeChat executable / 微信主程序" "${APP_EXECUTABLE_PATH}"
    print_binary_info "Plugin framework / 插件 framework" "${PLUGIN_SRC_BINARY_PATH}"
    echo ""

    # 插件需要至少支持当前微信主程序能运行的架构。
    # 对普通用户分发时，强烈建议插件做 universal。
    if binary_contains_arch "${APP_EXECUTABLE_PATH}" "${HOST_ARCH}"; then
        if ! binary_contains_arch "${PLUGIN_SRC_BINARY_PATH}" "${HOST_ARCH}"; then
            die "Plugin framework does not support host arch ${HOST_ARCH} / 插件不支持当前机器架构 ${HOST_ARCH}，拒绝安装"
        fi
    else
        die "WeChat executable does not support host arch ${HOST_ARCH} / 微信主程序不支持当前机器架构 ${HOST_ARCH}"
    fi

    ok "Architecture pre-check finished / 架构预检查完成"
}

# ------------------------------
# version check
# ------------------------------

check_supported_version() {
    APP_SHORT_VERSION="$(read_plist CFBundleShortVersionString)"
    APP_BUILD_VERSION="$(read_plist CFBundleVersion)"

    [ -n "${APP_SHORT_VERSION}" ] || die "Failed to read CFBundleShortVersionString / 读取微信版本号失败"
    [ -n "${APP_BUILD_VERSION}" ] || die "Failed to read CFBundleVersion / 读取微信 build 号失败"

    MATCHED_DISPLAY_VERSION=""
    MATCHED_LINE=""
    MATCHED_FAT_SHA256=""
    MATCHED_ARM64_UUID=""

    echo ""
    info "Detected WeChat version / 检测到微信版本:"
    echo "    CFBundleShortVersionString: ${APP_SHORT_VERSION}"
    echo "    CFBundleVersion:            ${APP_BUILD_VERSION}"
    echo ""

    while IFS='|' read -r f1 f2 f3 f4 f5 f6 rest || [ -n "${f1:-}" ]; do
        f1="$(trim "${f1:-}")"
        f2="$(trim "${f2:-}")"
        f3="$(trim "${f3:-}")"
        f4="$(trim "${f4:-}")"
        f5="$(trim "${f5:-}")"
        f6="$(trim "${f6:-}")"

        [ -z "${f1}" ] && continue
        [[ "${f1}" == \#* ]] && continue

        local display_version=""
        local short_version=""
        local build_version=""
        local note=""
        local fat_sha256=""
        local arm64_uuid=""

        # 新格式：DisplayVersion|CFBundleShortVersionString|CFBundleVersion|Note|FatSHA256|Arm64UUID
        # 兼容旧格式：CFBundleShortVersionString|CFBundleVersion|Note
        if [ -n "${f3}" ] && is_build_token "${f3}"; then
            display_version="${f1}"
            short_version="${f2}"
            build_version="${f3}"
            note="${f4}"
            fat_sha256="${f5}"
            arm64_uuid="${f6}"
        else
            display_version="${f1}"
            short_version="${f1}"
            build_version="${f2}"
            note="${f3}"
        fi

        [ -z "${short_version}" ] && short_version="*"
        [ -z "${build_version}" ] && build_version="*"

        if { [ "${short_version}" = "${APP_SHORT_VERSION}" ] || [ "${short_version}" = "*" ]; } && \
           { [ "${build_version}" = "${APP_BUILD_VERSION}" ] || [ "${build_version}" = "*" ]; }; then
            MATCHED_DISPLAY_VERSION="${display_version}"
            MATCHED_LINE="${display_version}|${short_version}|${build_version}|${note}"
            MATCHED_FAT_SHA256="${fat_sha256}"
            MATCHED_ARM64_UUID="${arm64_uuid}"
            break
        fi
    done < "${SUPPORTED_FILE}"

    if [ -n "${MATCHED_DISPLAY_VERSION}" ]; then
        ok "Version supported / 版本检查通过"
        echo "    Supported Display Version: ${MATCHED_DISPLAY_VERSION}"
        echo "    Matched Rule:              ${MATCHED_LINE}"
        echo ""

        BACKUP_PATH="${BACKUP_DIR}/${APP_NAME}.backup.${MATCHED_DISPLAY_VERSION}.${APP_BUILD_VERSION}"
        return 0
    fi

    warn "Current WeChat version is not listed in supported_versions.txt / 当前微信版本未在支持列表中"
    echo "    Detected CFBundleShortVersionString: ${APP_SHORT_VERSION}"
    echo "    Detected CFBundleVersion:            ${APP_BUILD_VERSION}"
    echo ""
    echo "    Please add a line like / 请添加类似下面这一行："
    echo "    4.1.9.58|${APP_SHORT_VERSION}|${APP_BUILD_VERSION}|Tested"
    echo ""

    BACKUP_PATH="${BACKUP_DIR}/${APP_NAME}.backup.${APP_SHORT_VERSION}.${APP_BUILD_VERSION}"

    if [ "${FORCE}" -eq 1 ]; then
        warn "Force mode enabled, continue anyway / 已使用 --force，继续安装"
        return 0
    fi

    read -r -p "Continue anyway? 是否仍然继续安装？[y/N] " answer
    case "${answer}" in
        y|Y|yes|YES)
            warn "User confirmed, continue installation / 用户确认继续安装"
            ;;
        *)
            die "Installation cancelled / 用户取消安装"
            ;;
    esac
}

check_exact_binary_profile() {
    if [ -z "${MATCHED_FAT_SHA256}" ] && [ -z "${MATCHED_ARM64_UUID}" ]; then
        warn "Matched version has no exact binary gate / 当前版本规则没有精确二进制门禁"
        return 0
    fi

    [ -n "${MATCHED_FAT_SHA256}" ] && [ -n "${MATCHED_ARM64_UUID}" ] || \
        die "Incomplete exact binary profile / 精确二进制规则缺少 SHA-256 或 arm64 UUID"

    command_required shasum
    command_required dwarfdump
    command_required tr

    local target_dylib="${APP_PATH}/Contents/Resources/wechat.dylib"
    local actual_sha256=""
    local uuid_output=""
    local actual_arm64_uuid=""
    local expected_sha256=""
    local expected_arm64_uuid=""

    [ -f "${target_dylib}" ] || die "Target wechat.dylib not found / 找不到目标 wechat.dylib: ${target_dylib}"

    info "Verify exact WeChat binary profile / 校验精确微信二进制样本..."
    expected_sha256="$(printf '%s' "${MATCHED_FAT_SHA256}" | tr '[:upper:]' '[:lower:]')"
    actual_sha256="$(shasum -a 256 "${target_dylib}" | awk '{print $1}')" || \
        die "Failed to hash target wechat.dylib / 无法计算目标 wechat.dylib 的 SHA-256"
    actual_sha256="$(printf '%s' "${actual_sha256}" | tr '[:upper:]' '[:lower:]')"
    [ "${actual_sha256}" = "${expected_sha256}" ] || \
        die "Target wechat.dylib SHA-256 mismatch / 目标 wechat.dylib SHA-256 不匹配（expected ${expected_sha256}, got ${actual_sha256}）"

    uuid_output="$(dwarfdump --uuid "${target_dylib}" 2>/dev/null)" || \
        die "Failed to read target Mach-O UUID / 无法读取目标 Mach-O UUID"
    actual_arm64_uuid="$(printf '%s\n' "${uuid_output}" | awk '$1 == "UUID:" && $3 == "(arm64)" {print $2}')"
    expected_arm64_uuid="$(printf '%s' "${MATCHED_ARM64_UUID}" | tr '[:lower:]' '[:upper:]')"
    actual_arm64_uuid="$(printf '%s' "${actual_arm64_uuid}" | tr '[:lower:]' '[:upper:]')"
    [ "${actual_arm64_uuid}" = "${expected_arm64_uuid}" ] || \
        die "Target arm64 UUID mismatch / 目标 arm64 UUID 不匹配（expected ${expected_arm64_uuid}, got ${actual_arm64_uuid:-missing-or-duplicate}）"

    ok "Exact binary profile verified / 精确二进制样本校验通过"
    echo "    wechat.dylib SHA-256: ${actual_sha256}"
    echo "    arm64 UUID:           ${actual_arm64_uuid}"
    echo ""
}

# ------------------------------
# install steps
# ------------------------------

prepare_sudo() {
    RUN_SUDO=0
    local app_parent_path=""

    app_parent_path="$(dirname "${APP_PATH}")"

    if [ ! -w "${MACOS_PATH}" ] || [ ! -w "${APP_EXECUTABLE_PATH}" ] || [ ! -w "${app_parent_path}" ] || \
       { [ -d "${BACKUP_DIR}" ] && [ ! -w "${BACKUP_DIR}" ]; }; then
        RUN_SUDO=1
        info "Administrator permission required / 需要管理员权限，准备申请 sudo..."
        sudo -v
    fi
}

quit_wechat() {
    info "Quit WeChat / 退出微信..."

    if [ "${IS_SYSTEM_APP}" -ne 1 ]; then
        warn "Custom app path: skip global WeChat process control; make sure this copy is not running / 自定义 App 路径：不操作系统微信进程，请确认该副本未运行"
        return 0
    fi

    osascript -e 'tell application "WeChat" to quit' >/dev/null 2>&1 || true
    sleep 1

    pkill -x WeChat >/dev/null 2>&1 || true

    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if ! pgrep -x WeChat >/dev/null 2>&1; then
            ok "WeChat is not running / 微信已退出"
            return 0
        fi
        sleep 0.5
    done

    if pgrep -x WeChat >/dev/null 2>&1; then
        warn "WeChat is still running, force kill / 微信仍在运行，强制结束"
        pkill -9 -x WeChat >/dev/null 2>&1 || true
    fi
}

remove_quarantine() {
    info "Remove quarantine attribute / 移除 quarantine 属性..."

    xattr -rd com.apple.quarantine "${INSERT_DYLIB_PATH}" >/dev/null 2>&1 || true
    xattr -rd com.apple.quarantine "${PLUGIN_SRC_PATH}" >/dev/null 2>&1 || true
    run_cmd xattr -rd com.apple.quarantine "${APP_PATH}" >/dev/null 2>&1 || true

    ok "Quarantine handled / quarantine 属性已处理"
}

is_executable_injected() {
    local executable="$1"
    local load_commands=""

    [ -f "${executable}" ] || return 2

    load_commands="$(otool -l "${executable}" 2>/dev/null)" || return 2

    # pipefail 下 grep -q 提前退出可能使 otool 收到 SIGPIPE，导致已注入被误判为未注入。
    # 先完整读取 otool 输出，再匹配加载项；otool 失败时返回 2，不能当成干净文件。
    printf '%s\n' "${load_commands}" | grep -F "${LOAD_DYLIB_PATH}" >/dev/null && return 0
    printf '%s\n' "${load_commands}" | grep -F "${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" >/dev/null && return 0

    return 1
}

is_executable_clean() {
    local status=0

    if is_executable_injected "$1"; then
        return 1
    else
        status="$?"
    fi

    [ "${status}" -eq 1 ]
}

macho_uuids() {
    local executable="$1"
    otool -l "${executable}" 2>/dev/null | awk '$1 == "uuid" {print $2}' | sort
}

same_macho_uuids() {
    local left="$1"
    local right="$2"
    local left_uuids="" right_uuids=""

    left_uuids="$(macho_uuids "${left}")" || left_uuids=""
    right_uuids="$(macho_uuids "${right}")" || right_uuids=""

    [ -n "${left_uuids}" ] && [ "${left_uuids}" = "${right_uuids}" ]
}

backup_executable() {
    info "Backup original executable / 备份微信主可执行文件..."

    [ ! -L "${BACKUP_DIR}" ] || die "Backup directory must not be a symbolic link / 备份目录不能是符号链接: ${BACKUP_DIR}"
    run_cmd mkdir -p "${BACKUP_DIR}"

    [ ! -L "${BACKUP_PATH}" ] || die "Backup must not be a symbolic link / 备份文件不能是符号链接: ${BACKUP_PATH}"
    if [ -e "${BACKUP_PATH}" ] && [ ! -f "${BACKUP_PATH}" ]; then
        die "Backup path exists but is not a regular file / 备份路径已存在但不是普通文件: ${BACKUP_PATH}"
    fi

    if [ -f "${BACKUP_PATH}" ]; then
        is_executable_clean "${BACKUP_PATH}" || die "Backup is injected or cannot be inspected / 备份文件已注入或无法完整检查，请先移走并重新安装微信: ${BACKUP_PATH}"

        if ! same_macho_uuids "${APP_EXECUTABLE_PATH}" "${BACKUP_PATH}"; then
            die "Backup UUID does not match current WeChat / 备份与当前微信 UUID 不一致，请先移走旧备份: ${BACKUP_PATH}"
        fi

        ok "Backup already exists / 备份已存在: ${BACKUP_PATH}"
        return 0
    fi

    if ! is_executable_clean "${APP_EXECUTABLE_PATH}"; then
        if ! is_executable_injected "${APP_EXECUTABLE_PATH}"; then
            die "Cannot inspect current WeChat executable / 无法检查当前微信主程序的加载项"
        fi

        # Older installers kept backups inside the app bundle. Move only a clean,
        # UUID-matching copy outside the bundle so deep signing cannot rewrite it.
        local legacy_backup=""
        local candidate=""
        local current_uuids="" legacy_uuids=""

        current_uuids="$(otool -l "${APP_EXECUTABLE_PATH}" | awk '$1 == "uuid" {print $2}' | sort)" || current_uuids=""

        for candidate in "${APP_EXECUTABLE_PATH}_backup" "${APP_EXECUTABLE_PATH}.backup."*; do
            [ -f "${candidate}" ] || continue
            [ ! -L "${candidate}" ] || continue
            is_executable_clean "${candidate}" || continue

            legacy_backup="${candidate}"
            legacy_uuids="$(macho_uuids "${legacy_backup}")" || legacy_uuids=""
            if [ -n "${current_uuids}" ] && [ "${current_uuids}" = "${legacy_uuids}" ]; then
                INSTALL_ROLLBACK_READY=1
                run_cmd mv "${legacy_backup}" "${BACKUP_PATH}"
                ok "Migrated clean Xcode backup / 已迁移匹配当前程序的干净 Xcode 备份"
                return 0
            fi
        done
        die "WeChat executable is already injected, but clean backup is missing / 当前微信主程序已被注入，但没有干净备份。请先重新安装微信或恢复原版"
    fi

    local temporary_backup=""
    temporary_backup="$(run_cmd mktemp "${BACKUP_PATH}.partial.XXXXXX")" || die "Failed to allocate temporary backup / 无法创建临时备份文件"

    if ! run_cmd cp -p "${APP_EXECUTABLE_PATH}" "${temporary_backup}" || \
       ! run_cmd cmp -s "${APP_EXECUTABLE_PATH}" "${temporary_backup}"; then
        run_cmd rm -f "${temporary_backup}" || true
        die "Backup copy verification failed / 备份复制校验失败，未写入正式备份"
    fi

    if ! run_cmd mv "${temporary_backup}" "${BACKUP_PATH}"; then
        run_cmd rm -f "${temporary_backup}" || true
        die "Failed to publish verified backup / 无法保存已校验的正式备份"
    fi

    ok "Backup created / 已创建备份: ${BACKUP_PATH}"
}

restore_clean_executable() {
    info "Restore clean executable from backup / 从备份恢复干净主程序..."

    [ -f "${BACKUP_PATH}" ] || die "Backup not found / 备份不存在: ${BACKUP_PATH}"

    [ ! -L "${BACKUP_PATH}" ] || die "Backup must not be a symbolic link / 备份文件不能是符号链接: ${BACKUP_PATH}"
    is_executable_clean "${BACKUP_PATH}" || die "Backup is injected or cannot be inspected / 备份文件已注入或无法完整检查: ${BACKUP_PATH}"
    same_macho_uuids "${APP_EXECUTABLE_PATH}" "${BACKUP_PATH}" || die "Backup UUID does not match current WeChat / 备份与当前微信 UUID 不一致: ${BACKUP_PATH}"

    run_cmd cp -p "${BACKUP_PATH}" "${APP_EXECUTABLE_PATH}"
    run_cmd chmod +x "${APP_EXECUTABLE_PATH}"

    ok "Executable restored / 主程序已恢复为干净版本"
}

copy_framework() {
    info "Copy plugin framework / 拷贝插件 framework..."

    run_cmd rm -rf "${FRAMEWORK_DST_PATH}"
    run_cmd ditto "${PLUGIN_SRC_PATH}" "${FRAMEWORK_DST_PATH}"

    [ -f "${FRAMEWORK_DST_BINARY_PATH}" ] || die "Copied framework binary missing / 拷贝后的 framework 二进制不存在: ${FRAMEWORK_DST_BINARY_PATH}"

    run_cmd chmod +x "${FRAMEWORK_DST_BINARY_PATH}" || true
    run_cmd xattr -rd com.apple.quarantine "${FRAMEWORK_DST_PATH}" >/dev/null 2>&1 || true

    ok "Framework copied / 插件 framework 已拷贝"
}

run_insert_dylib_tool() {
    if [ -n "${INSERT_DYLIB_RUNNER}" ]; then
        /usr/bin/arch -x86_64 "${INSERT_DYLIB_PATH}" --all-yes "${LOAD_DYLIB_PATH}" "${BACKUP_PATH}" "${APP_EXECUTABLE_PATH}"
    else
        "${INSERT_DYLIB_PATH}" --all-yes "${LOAD_DYLIB_PATH}" "${BACKUP_PATH}" "${APP_EXECUTABLE_PATH}"
    fi
}

insert_framework() {
    info "Insert LC_LOAD_DYLIB / 注入 LC_LOAD_DYLIB..."
    echo "    ${LOAD_DYLIB_PATH}"

    chmod +x "${INSERT_DYLIB_PATH}" || true
    xattr -rd com.apple.quarantine "${INSERT_DYLIB_PATH}" >/dev/null 2>&1 || true

    local output=""
    local status=0

    set +e
    if [ "${RUN_SUDO}" -eq 1 ]; then
        if [ -n "${INSERT_DYLIB_RUNNER}" ]; then
            output="$(sudo /usr/bin/arch -x86_64 "${INSERT_DYLIB_PATH}" --all-yes "${LOAD_DYLIB_PATH}" "${BACKUP_PATH}" "${APP_EXECUTABLE_PATH}" 2>&1)"
            status="$?"
        else
            output="$(sudo "${INSERT_DYLIB_PATH}" --all-yes "${LOAD_DYLIB_PATH}" "${BACKUP_PATH}" "${APP_EXECUTABLE_PATH}" 2>&1)"
            status="$?"
        fi
    else
        output="$(run_insert_dylib_tool 2>&1)"
        status="$?"
    fi
    set -e

    if [ -n "${output}" ]; then
        echo "${output}"
    fi

    if [ "${status}" -ne 0 ]; then
        if echo "${output}" | grep -qi "Bad CPU type"; then
            echo ""
            echo "    Host Arch: ${HOST_ARCH}"
            print_binary_info "insert_dylib" "${INSERT_DYLIB_PATH}"
            echo ""
            die "insert_dylib failed: Bad CPU type in executable / insert_dylib 架构不匹配。请把 Rely/insert_dylib 换成 universal，或放入 insert_dylib_${HOST_ARCH}"
        fi

        die "insert_dylib failed with exit code ${status} / insert_dylib 执行失败，退出码 ${status}"
    fi

    run_cmd chmod +x "${APP_EXECUTABLE_PATH}"
    ok "Dylib inserted / 注入完成"
}

sign_app() {
    info "Ad-hoc code sign plugin framework / 对插件 framework 执行 ad-hoc 签名..."
    run_cmd codesign --force --deep --sign - --timestamp=none "${FRAMEWORK_DST_PATH}"

    sign_embedded_and_main_app
}

sign_embedded_and_main_app() {
    local app_ex_path="${MACOS_PATH}/WeChatAppEx.app"
    local weapp_path=""

    info "Ad-hoc code sign WeChatAppEx if exists / 如果存在则对 WeChatAppEx 执行 ad-hoc 签名..."

    if [ -d "${app_ex_path}" ]; then
        run_cmd xattr -rd com.apple.quarantine "${app_ex_path}" >/dev/null 2>&1 || true
        run_cmd codesign --force --deep --sign - --timestamp=none "${app_ex_path}" || true

        weapp_path="${app_ex_path}/Contents/Frameworks/WeChatAppEx Framework.framework/Versions/C/Helpers/WeApp.app"
        if [ -d "${weapp_path}" ]; then
            run_cmd codesign --force --deep --sign - --timestamp=none "${weapp_path}" || true
        fi
    fi

    info "Ad-hoc code sign main WeChat.app / 对主 WeChat.app 执行 ad-hoc 签名..."
    run_cmd codesign --force --deep --sign - --timestamp=none "${APP_PATH}"

    ok "Ad-hoc code sign finished / ad-hoc 签名完成"
}

rollback_install_on_exit() {
    local status="$1"
    local clean_state=0

    if [ "${status}" -eq 0 ] || [ "${INSTALL_ROLLBACK_READY}" -ne 1 ] || [ "${INSTALL_COMPLETED}" -eq 1 ]; then
        return 0
    fi

    trap - EXIT
    set +e

    warn "Installation failed; restore the clean executable and remove partial files / 安装失败，开始恢复干净主程序并清理未完成内容"

    if [ -f "${BACKUP_PATH}" ] && [ ! -L "${BACKUP_PATH}" ] && \
       is_executable_clean "${BACKUP_PATH}" && \
       same_macho_uuids "${APP_EXECUTABLE_PATH}" "${BACKUP_PATH}"; then
        if run_cmd cp -p "${BACKUP_PATH}" "${APP_EXECUTABLE_PATH}" && \
           run_cmd chmod +x "${APP_EXECUTABLE_PATH}" && \
           is_executable_clean "${APP_EXECUTABLE_PATH}"; then
            clean_state=1
        fi
    elif is_executable_clean "${APP_EXECUTABLE_PATH}"; then
        clean_state=1
    fi

    if [ "${clean_state}" -eq 1 ]; then
        run_cmd rm -rf "${FRAMEWORK_DST_PATH}"
        run_cmd rm -f "${STATE_FILE}"
        sign_embedded_and_main_app
    else
        warn "Clean executable was not restored; keep framework and state to avoid breaking an injected executable / 未能恢复干净主程序，保留 framework 和状态文件，避免已注入程序缺少依赖"
    fi

    if [ "${clean_state}" -eq 1 ] && is_executable_clean "${APP_EXECUTABLE_PATH}" && codesign -vvv --deep --strict "${APP_PATH}" >/dev/null 2>&1; then
        ok "Failure recovery verified; backup kept / 安装失败恢复已验证，外置备份已保留"
    else
        warn "Automatic recovery could not be fully verified; keep the backup and reinstall official WeChat if needed / 自动恢复未能完整验证，请保留备份，必要时重装官方微信"
    fi

    exit "${status}"
}

write_state_file() {
    local temporary_state=""
    local state_contents=""

    info "Write install state / 写入安装状态..."

    [ ! -L "${STATE_FILE}" ] || die "Install state must not be a symbolic link / 安装状态文件不能是符号链接: ${STATE_FILE}"
    if [ -e "${STATE_FILE}" ] && [ ! -f "${STATE_FILE}" ]; then
        die "Install state path is not a regular file / 安装状态路径不是普通文件: ${STATE_FILE}"
    fi

    temporary_state="$(run_cmd mktemp "${STATE_FILE}.partial.XXXXXX")" || die "Failed to allocate temporary install state / 无法创建临时安装状态文件"
    state_contents="$(printf '%s\n' \
        "framework=${FRAMEWORK_NAME}" \
        "display_version=${MATCHED_DISPLAY_VERSION:-unknown}" \
        "short_version=${APP_SHORT_VERSION}" \
        "build_version=${APP_BUILD_VERSION}" \
        "host_arch=${HOST_ARCH}" \
        "insert_dylib=${INSERT_DYLIB_PATH}" \
        "insert_dylib_run_mode=${INSERT_DYLIB_RUN_MODE}" \
        "backup=${BACKUP_PATH}" \
        "load_dylib=${LOAD_DYLIB_PATH}" \
        "installed_at=$(date '+%Y-%m-%d %H:%M:%S')")"

    if ! printf '%s\n' "${state_contents}" | run_cmd tee "${temporary_state}" >/dev/null; then
        run_cmd rm -f "${temporary_state}" || true
        die "Failed to write install state / 写入安装状态失败"
    fi

    if ! run_cmd chmod 0644 "${temporary_state}"; then
        run_cmd rm -f "${temporary_state}" || true
        die "Failed to set install state permissions / 无法设置安装状态文件权限"
    fi

    if ! run_cmd mv "${temporary_state}" "${STATE_FILE}"; then
        run_cmd rm -f "${temporary_state}" || true
        die "Failed to publish install state / 无法保存安装状态"
    fi

    ok "Install state saved / 安装状态已保存: ${STATE_FILE}"
}

verify_install() {
    info "Verify inserted dylib / 检查注入结果..."

    if is_executable_injected "${APP_EXECUTABLE_PATH}"; then
        ok "LC_LOAD_DYLIB found / 已检测到 ${FRAMEWORK_NAME}"
        otool -l "${APP_EXECUTABLE_PATH}" | grep -A3 "${FRAMEWORK_NAME}" || true
    else
        die "LC_LOAD_DYLIB not found / 未检测到 ${FRAMEWORK_NAME}，注入可能失败"
    fi

    echo ""
    info "Verify code signature / 检查签名..."

    if codesign -vvv --deep --strict "${APP_PATH}" >/dev/null 2>&1; then
        ok "Ad-hoc deep signature verified / ad-hoc 深度签名验证通过"
    else
        die "Code signature verification failed / 签名验证失败，未清除权限"
    fi
}

reset_app_data_permission() {
    # Only the installed WeChat's container permission; never reset All or FDA.
    if [ "${IS_SYSTEM_APP}" -ne 1 ]; then
        warn "Custom app path: skip global TCC reset / 自定义 App 路径：不重置系统微信的全局 TCC 授权"
        return 0
    fi

    if [ "$(read_plist CFBundleIdentifier)" != "com.tencent.xinWeChat" ]; then
        warn "Not the standard WeChat bundle / 非标准微信标识，未清除数据访问权限"
        return 0
    fi

    local output=""
    local result=0
    if [ "${EUID}" -eq 0 ]; then
        if [ -z "${SUDO_USER:-}" ] || [ "${SUDO_USER}" = "root" ]; then
            warn "No installing user / 无法确定安装用户，未清除数据访问旧授权"
            return 0
        fi
        output="$(sudo -u "${SUDO_USER}" /usr/bin/tccutil reset SystemPolicyAppDataDetailed com.tencent.xinWeChat 2>&1)" || result=$?
    else
        output="$(/usr/bin/tccutil reset SystemPolicyAppDataDetailed com.tencent.xinWeChat 2>&1)" || result=$?
    fi
    if [ "${result}" -eq 0 ]; then
        ok "微信数据访问旧授权已清除；请打开微信重新授权"
    else
        # This service is accepted on macOS 27; do not broaden the reset on older systems.
        warn "微信已安装，但数据访问旧授权未清除；请在系统设置中手动处理"
        echo "    ${output}"
    fi
}

print_done() {
    echo ""
    echo "=============================="
    echo "✅ ${FRAMEWORK_NAME} installed successfully"
    echo "✅ ${FRAMEWORK_NAME} 安装完成"
    echo "=============================="
    echo ""
    echo "Detected / 检测信息："
    echo "  WeChat:      ${APP_SHORT_VERSION} (${APP_BUILD_VERSION})"
    echo "  Display:     ${MATCHED_DISPLAY_VERSION:-unknown}"
    echo "  Host Arch:   ${HOST_ARCH}"
    echo "  Tool:        ${INSERT_DYLIB_PATH}"
    echo "  Tool Mode:   ${INSERT_DYLIB_RUN_MODE}"
    echo "  Backup:      ${BACKUP_PATH}"
    echo ""
    echo "Run WeChat and watch log / 启动微信并查看日志："
    echo "  rm -f ${LOG_PATH}"
    echo "  open -a WeChat"
    echo "  tail -f ${LOG_PATH}"
    echo ""
    echo "Uninstall / 卸载："
    echo "  ${SCRIPT_DIR}/uninstall.sh"
    echo ""
}

# ------------------------------
# main
# ------------------------------

echo "=============================="
echo " Install ${FRAMEWORK_NAME}"
echo "=============================="
echo "APP_PATH=${APP_PATH}"
echo "PLUGIN_SRC_PATH=${PLUGIN_SRC_PATH}"
echo "FRAMEWORK_DST_PATH=${FRAMEWORK_DST_PATH}"
echo "SUPPORTED_FILE=${SUPPORTED_FILE}"
echo "LOAD_DYLIB_PATH=${LOAD_DYLIB_PATH}"
echo ""

check_required_commands
check_basic_files
select_insert_dylib
check_arch_compatibility
check_supported_version
check_exact_binary_profile
prepare_sudo
quit_wechat
remove_quarantine
trap 'rollback_install_on_exit "$?"' EXIT
backup_executable
INSTALL_ROLLBACK_READY=1
restore_clean_executable
copy_framework
insert_framework
if [ "${WRITE_INSTALL_STATE}" -eq 1 ]; then
    write_state_file
fi
sign_app
verify_install
INSTALL_COMPLETED=1
reset_app_data_permission
print_done
