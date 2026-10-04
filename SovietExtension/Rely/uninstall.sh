#!/bin/bash

# 如果用户用 sh uninstall.sh 执行，自动切换到 bash
# If user runs this script with sh, re-exec with bash.
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi

set -euo pipefail

# ==============================
# SovietExtension uninstaller
# ==============================

APP_NAME="WeChat"
FRAMEWORK_NAME="${FRAMEWORK_NAME:-SovietExtension}"
APP_PATH="/Applications/${APP_NAME}.app"
STANDARD_APP_PATH="/Applications/${APP_NAME}.app"
IS_SYSTEM_APP=0
FORCE=0
REMOVE_BACKUP=0
RUN_SUDO=0
UNINSTALL_MUTATION_STARTED=0
UNINSTALL_APP_VERIFIED=0

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
    cat <<EOF
Usage:
  ./uninstall.sh
  sh uninstall.sh
  ./uninstall.sh --remove-backup
  ./uninstall.sh --force
  ./uninstall.sh --app=/Applications/WeChat.app

Options:
  --force              Select another backup; UUID must still match / 可选择其他备份，但 UUID 仍须匹配
  --remove-backup      Remove backup files after uninstall / 卸载后删除备份
  --app=PATH           Specify WeChat.app path / 指定 WeChat.app 路径
  --framework=NAME     Specify framework name, default: SovietExtension / 指定插件名，默认 SovietExtension
  -h, --help           Show help / 显示帮助

EOF
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
        --remove-backup)
            REMOVE_BACKUP=1
            ;;
        --app=*)
            APP_PATH="${arg#--app=}"
            ;;
        --framework=*)
            FRAMEWORK_NAME="${arg#--framework=}"
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

FRAMEWORK_DST_PATH="${MACOS_PATH}/${FRAMEWORK_NAME}.framework"
STATE_FILE="${MACOS_PATH}/.${FRAMEWORK_NAME}.install_state"
LOAD_DYLIB_PATH="@executable_path/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}"

read_plist() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :${key}" "${INFO_PLIST}" 2>/dev/null || true
}

read_state_value() {
    local key="$1"

    if [ ! -f "${STATE_FILE}" ]; then
        return 0
    fi

    grep "^${key}=" "${STATE_FILE}" 2>/dev/null | head -n 1 | sed "s/^${key}=//" || true
}

check_basic_files() {
    [ -d "${APP_PATH}" ] || die "WeChat.app not found / 找不到 WeChat.app: ${APP_PATH}"
    [ -f "${INFO_PLIST}" ] || die "Info.plist not found / 找不到 Info.plist: ${INFO_PLIST}"
    [ -f "${APP_EXECUTABLE_PATH}" ] || die "WeChat executable not found / 找不到微信主可执行文件: ${APP_EXECUTABLE_PATH}"
    [ ! -L "${BACKUP_DIR}" ] || die "Backup directory must not be a symbolic link / 备份目录不能是符号链接: ${BACKUP_DIR}"
    if [ -e "${BACKUP_DIR}" ] && [ ! -d "${BACKUP_DIR}" ]; then
        die "Backup directory path is not a directory / 备份目录路径不是目录: ${BACKUP_DIR}"
    fi
    [ ! -L "${STATE_FILE}" ] || die "Install state must not be a symbolic link / 安装状态文件不能是符号链接: ${STATE_FILE}"
    if [ -e "${STATE_FILE}" ] && [ ! -f "${STATE_FILE}" ]; then
        die "Install state path is not a regular file / 安装状态路径不是普通文件: ${STATE_FILE}"
    fi
}

is_allowed_backup_path() {
    local backup_path="$1"
    local backup_parent=""
    local backup_name=""

    backup_parent="$(dirname "${backup_path}")"
    backup_name="$(basename "${backup_path}")"

    if [ "${backup_parent}" = "${BACKUP_DIR}" ]; then
        case "${backup_name}" in
            "${APP_NAME}.backup."*) return 0 ;;
        esac
    fi

    if [ "${backup_parent}" = "${MACOS_PATH}" ]; then
        case "${backup_name}" in
            "${APP_NAME}_backup"|"${APP_NAME}.backup."*) return 0 ;;
        esac
    fi

    return 1
}

prepare_version_and_backup() {
    APP_SHORT_VERSION="$(read_plist CFBundleShortVersionString)"
    APP_BUILD_VERSION="$(read_plist CFBundleVersion)"

    [ -n "${APP_SHORT_VERSION}" ] || die "Failed to read CFBundleShortVersionString / 读取微信版本号失败"
    [ -n "${APP_BUILD_VERSION}" ] || die "Failed to read CFBundleVersion / 读取微信 build 号失败"

    echo ""
    info "Detected WeChat version / 检测到微信版本:"
    echo "    CFBundleShortVersionString: ${APP_SHORT_VERSION}"
    echo "    CFBundleVersion:            ${APP_BUILD_VERSION}"
    echo ""

    BACKUP_PATH_FROM_STATE="$(read_state_value backup)"
    if [ -n "${BACKUP_PATH_FROM_STATE}" ]; then
        BACKUP_PATH="${BACKUP_PATH_FROM_STATE}"
        is_allowed_backup_path "${BACKUP_PATH}" || die "Unsafe backup path in install state / 安装状态中的备份路径不安全: ${BACKUP_PATH}"
        info "Backup path from install state / 从安装状态读取备份路径:"
        echo "    ${BACKUP_PATH}"
    else
        BACKUP_PATH="${BACKUP_DIR}/${APP_NAME}.backup.${APP_SHORT_VERSION}.${APP_BUILD_VERSION}"
        info "Backup path by current version / 按当前版本推导备份路径:"
        echo "    ${BACKUP_PATH}"
    fi

    if [ -f "${BACKUP_PATH}" ]; then
        ok "Backup found / 找到备份"
        return 0
    fi

    local candidate=""
    candidate="$(ls -t "${BACKUP_DIR}/${APP_NAME}.backup."* "${APP_EXECUTABLE_PATH}.backup."* "${APP_EXECUTABLE_PATH}_backup" 2>/dev/null | head -n 1 || true)"

    if [ -n "${candidate}" ]; then
        warn "Exact backup not found, but another backup exists / 未找到精确备份，但找到了其他备份:"
        echo "    ${candidate}"

        if [ "${FORCE}" -eq 1 ]; then
            warn "Force mode enabled, use this backup / 已使用 --force，将使用该备份恢复"
            BACKUP_PATH="${candidate}"
            return 0
        fi

        read -r -p "Use this backup to restore? 是否使用这个备份恢复？[y/N] " answer
        case "${answer}" in
            y|Y|yes|YES)
                BACKUP_PATH="${candidate}"
                ;;
            *)
                warn "User refused non-current backup / 用户拒绝使用非当前版本备份"
                ;;
        esac
    fi
}

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

is_executable_injected() {
    local executable="$1"
    local load_commands=""

    [ -f "${executable}" ] || return 2

    load_commands="$(otool -l "${executable}" 2>/dev/null)" || return 2

    # Do not use grep -q with pipefail: an early match can SIGPIPE otool and
    # turn a real match into a false negative. Inspection failure returns 2.
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

validate_backup_if_present() {
    is_allowed_backup_path "${BACKUP_PATH}" || die "Backup path is outside the allowed directories / 备份路径不在允许目录内: ${BACKUP_PATH}"
    [ ! -L "${BACKUP_PATH}" ] || die "Backup must not be a symbolic link / 备份文件不能是符号链接: ${BACKUP_PATH}"
    if [ -e "${BACKUP_PATH}" ] && [ ! -f "${BACKUP_PATH}" ]; then
        die "Backup path exists but is not a regular file / 备份路径已存在但不是普通文件: ${BACKUP_PATH}"
    fi
    [ -f "${BACKUP_PATH}" ] || return 0

    is_executable_clean "${BACKUP_PATH}" || die "Backup is injected or cannot be inspected / 备份文件已注入或无法完整检查: ${BACKUP_PATH}"

    if ! same_macho_uuids "${APP_EXECUTABLE_PATH}" "${BACKUP_PATH}"; then
        die "Backup UUID does not match current WeChat / 备份与当前微信 UUID 不一致: ${BACKUP_PATH}"
    fi

    ok "Backup safety checks passed / 备份路径、注入状态和 UUID 校验通过"
}

migrate_legacy_backup() {
    local backup_parent=""
    local destination=""
    local legacy_backup=""

    [ -f "${BACKUP_PATH}" ] || return 0
    backup_parent="$(dirname "${BACKUP_PATH}")"
    [ "${backup_parent}" = "${MACOS_PATH}" ] || return 0

    destination="${BACKUP_DIR}/${APP_NAME}.backup.${APP_SHORT_VERSION}.${APP_BUILD_VERSION}"
    run_cmd mkdir -p "${BACKUP_DIR}"

    [ ! -L "${destination}" ] || die "External backup must not be a symbolic link / 外置备份不能是符号链接: ${destination}"
    if [ -e "${destination}" ] && [ ! -f "${destination}" ]; then
        die "External backup path is not a regular file / 外置备份路径不是普通文件: ${destination}"
    fi

    legacy_backup="${BACKUP_PATH}"

    if [ -f "${destination}" ]; then
        same_macho_uuids "${APP_EXECUTABLE_PATH}" "${destination}" || die "Existing external backup UUID mismatch / 已有外置备份 UUID 不一致: ${destination}"
        is_executable_clean "${destination}" || die "Existing external backup is injected or cannot be inspected / 已有外置备份已注入或无法完整检查: ${destination}"
        BACKUP_PATH="${destination}"
        UNINSTALL_MUTATION_STARTED=1
        run_cmd rm -f "${legacy_backup}"
    else
        BACKUP_PATH="${destination}"
        UNINSTALL_MUTATION_STARTED=1
        run_cmd mv "${legacy_backup}" "${destination}"
    fi

    ok "Legacy in-app backup migrated outside the app / 旧式包内备份已迁移到 App 包外"
}

preflight_restore() {
    if [ ! -f "${BACKUP_PATH}" ] && ! is_executable_clean "${APP_EXECUTABLE_PATH}"; then
        die "Executable is injected or cannot be inspected, but backup is missing / 当前主程序仍含注入项或无法完整检查，且找不到备份，无法安全卸载"
    fi
}

restore_executable() {
    info "Restore original executable / 恢复微信主可执行文件..."

    if [ -f "${BACKUP_PATH}" ]; then
        [ ! -L "${BACKUP_PATH}" ] || die "Backup must not be a symbolic link / 备份文件不能是符号链接: ${BACKUP_PATH}"
        is_executable_clean "${BACKUP_PATH}" || die "Backup is injected or cannot be inspected / 备份文件已注入或无法完整检查: ${BACKUP_PATH}"
        same_macho_uuids "${APP_EXECUTABLE_PATH}" "${BACKUP_PATH}" || die "Backup UUID does not match current WeChat / 备份与当前微信 UUID 不一致: ${BACKUP_PATH}"
        run_cmd cp -p "${BACKUP_PATH}" "${APP_EXECUTABLE_PATH}"
        run_cmd chmod +x "${APP_EXECUTABLE_PATH}"
        ok "Executable restored from backup / 已从备份恢复: ${BACKUP_PATH}"
        return 0
    fi

    is_executable_clean "${APP_EXECUTABLE_PATH}" || die "Executable is injected or cannot be inspected, but backup is missing / 当前主程序仍含注入项或无法完整检查，且找不到备份，无法安全卸载"

    ok "No injected dylib found, skip restore / 未检测到插件注入项，跳过恢复"
}

remove_framework() {
    info "Remove plugin framework / 删除插件 framework..."

    if [ -d "${FRAMEWORK_DST_PATH}" ]; then
        run_cmd rm -rf "${FRAMEWORK_DST_PATH}"
        ok "Framework removed / 已删除: ${FRAMEWORK_DST_PATH}"
    else
        ok "Framework does not exist, skip / 插件 framework 不存在，跳过"
    fi

    if [ -f "${STATE_FILE}" ]; then
        run_cmd rm -f "${STATE_FILE}"
        ok "Install state removed / 安装状态已删除"
    fi
}

sign_app() {
    info "Ad-hoc code sign WeChatAppEx if exists / 如果存在则对 WeChatAppEx 执行 ad-hoc 签名..."
    APP_EX_PATH="${MACOS_PATH}/WeChatAppEx.app"

    if [ -d "${APP_EX_PATH}" ]; then
        run_cmd codesign --force --deep --sign - --timestamp=none "${APP_EX_PATH}" || true

        WEAPP_PATH="${APP_EX_PATH}/Contents/Frameworks/WeChatAppEx Framework.framework/Versions/C/Helpers/WeApp.app"
        if [ -d "${WEAPP_PATH}" ]; then
            run_cmd codesign --force --deep --sign - --timestamp=none "${WEAPP_PATH}" || true
        fi
    fi

    info "Ad-hoc code sign main WeChat.app / 对主 WeChat.app 执行 ad-hoc 签名..."
    run_cmd codesign --force --deep --sign - --timestamp=none "${APP_PATH}"

    ok "Ad-hoc code sign finished / ad-hoc 签名完成"
}

remove_backup_if_needed() {
    if [ "${REMOVE_BACKUP}" -ne 1 ]; then
        ok "Backup kept / 已保留备份文件"
        return 0
    fi

    info "Remove backup file / 删除本次安装对应的备份文件..."
    [ "$(dirname "${BACKUP_PATH}")" = "${BACKUP_DIR}" ] || die "Refuse to delete a non-external backup / 拒绝删除未迁移到外部目录的备份: ${BACKUP_PATH}"
    if [ -f "${BACKUP_PATH}" ]; then
        run_cmd rm -f "${BACKUP_PATH}"
    fi
    if [ -d "${BACKUP_DIR}" ]; then
        run_cmd rmdir "${BACKUP_DIR}" >/dev/null 2>&1 || true
    fi
    ok "Backup removed / 备份已删除"
}

verify_uninstall() {
    info "Verify uninstall / 检查卸载结果..."

    is_executable_clean "${APP_EXECUTABLE_PATH}" || die "Executable is still injected or cannot be inspected / 卸载后仍含 ${FRAMEWORK_NAME} 或无法完整检查主程序"

    ok "No injected LC_LOAD_DYLIB found / 已确认主程序中没有 ${FRAMEWORK_NAME}"

    echo ""
    info "Verify code signature / 检查签名..."

    codesign -vvv --deep --strict "${APP_PATH}" >/dev/null 2>&1 || die "Code signature verification failed / 签名验证失败，外置备份已保留"
    ok "Ad-hoc deep signature verified / ad-hoc 深度签名验证通过"
}

recover_uninstall_on_exit() {
    local status="$1"
    local clean_state=0

    if [ "${status}" -eq 0 ] || [ "${UNINSTALL_MUTATION_STARTED}" -ne 1 ] || [ "${UNINSTALL_APP_VERIFIED}" -eq 1 ]; then
        return 0
    fi

    trap - EXIT
    set +e

    warn "Uninstall failed; attempt a clean fail-safe recovery / 卸载失败，尝试恢复到无注入的可运行状态"

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
        sign_app
    else
        warn "Clean executable was not restored; keep framework and state to avoid breaking an injected executable / 未能恢复干净主程序，保留 framework 和状态文件，避免已注入程序缺少依赖"
    fi

    if [ "${clean_state}" -eq 1 ] && is_executable_clean "${APP_EXECUTABLE_PATH}" && codesign -vvv --deep --strict "${APP_PATH}" >/dev/null 2>&1; then
        ok "Fail-safe recovery verified; backup kept / 卸载失败恢复已验证，外置备份已保留"
    else
        warn "Fail-safe recovery could not be fully verified; keep the backup and reinstall official WeChat if needed / 失败恢复未能完整验证，请保留备份，必要时重装官方微信"
    fi

    exit "${status}"
}

print_done() {
    echo ""
    echo "=============================="
    echo "✅ ${FRAMEWORK_NAME} uninstalled successfully"
    echo "✅ ${FRAMEWORK_NAME} 卸载完成"
    echo "=============================="
    echo ""
    echo "Run WeChat / 启动微信："
    echo "  open -a WeChat"
    echo ""
}

echo "=============================="
echo " Uninstall ${FRAMEWORK_NAME}"
echo "=============================="
echo "APP_PATH=${APP_PATH}"
echo "FRAMEWORK_DST_PATH=${FRAMEWORK_DST_PATH}"
echo ""

check_basic_files
prepare_version_and_backup
validate_backup_if_present
prepare_sudo
quit_wechat
trap 'recover_uninstall_on_exit "$?"' EXIT
migrate_legacy_backup
preflight_restore
UNINSTALL_MUTATION_STARTED=1
restore_executable
remove_framework
sign_app
verify_uninstall
UNINSTALL_APP_VERIFIED=1
remove_backup_if_needed
print_done
