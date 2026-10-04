#!/usr/bin/env python3
"""Verify the exact fat or extracted arm64 Resources/wechat.dylib for 270102."""

import hashlib
import re
import struct
import sys
from pathlib import Path


ARM64 = 0x0100000C
ARM64_ALL = 0
FAT_MAGIC = b"\xca\xfe\xba\xbe"
OTHER_FAT_MAGICS = {b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
EXPECTED_FAT_SHA256 = "d89434bb90b65991aa35a32e6b48a5825b0b1906e7142b12387c32fd76996b94"
EXPECTED_SHA256 = "07e35c5d8ea0d97f1f16d79a5efec42fa1ca97213f634d473631beeaae8f0841"
EXPECTED_UUID = bytes.fromhex("3b7b6abb2c363e58a384cdef05a57aa5")
EXPECTED_SOURCE_FINGERPRINT_DIGEST = "fba9a5a28279b58be451854acda3d12c42f2891a913014198dd79b0349317264"
EXPECTED_MAPPING_DIGEST = "154c87db6198cd3d10b8ac557828eb7ce6ac4b7cac49cee3e049523c8006affd"
SOURCE_DIR = Path(__file__).resolve().parents[1] / "SovietExtension" / "SovietExtension"
EXPECTED_SOURCE_FILE_SHA256 = {
    "ForwardToSelfPatch.h": "70238450c892334a6e83ffffb383bab42263d30b2a93815336cc1970aec111ad",
    "ForwardToSelfPatch.mm": "f6a3b24d7cfe6e44fe039146cef20d526cfb25225eb505b262e1f7b24e5f75a3",
    "MenuManager.m": "2c2415ea5916db3c926374e8a8c02ff2425c12047be8d278c2cc79da772d28e1",
    "MessageMediaActions.mm": "fe4838f6795d86c47c383e0166d64c1d6b024c5f2a820d7459564e5da1ae181e",
    "MessageMenuPatch.h": "3fca14dcc536245ae6ca2be41350d0782288bfcfcef63e59fd2b8491074250cf",
    "MessageMenuPatch.mm": "efe19399b7d2eba6856275684db356df0a8930476dd86830a33179e138d1f934",
    "RevokePatch.mm": "e59c4757fb944a693c5080a3b6c5f08e525d620da31466c2aa1d94a91758f66d",
    "RevokeSettings.h": "123f6389a30cb0871a68946efcbd8fe801df4d99c80d323535e9beabef20cb43",
    "SelfRevokePatch.h": "72b392baef468e3ea546e51fafbd74dfffa1613866c35dc22934783e748c2d1f",
    "SelfRevokePatch.mm": "8a0a27776449897f856678299f5337b864285ee5b86c690ec7ac4f29b65f3be6",
    "SidebarManager.mm": "2590fae4529475dad406e85c8c09597e5af26f06fbbc8580414b9b36bf6b0075",
    "SidebarPatch.h": "9f4cbe10be1b6639f4f21f5ffb548e1a47933c0acc0b4de25da6432ad8aaa2b2",
    "SidebarPatch.mm": "57ef0df7d3f861e1dc65392c5b1ffc9b05a74355573e26296fc6d84c9f00afe0",
    "SidebarRuntime.h": "dee2dc8f5bb7caa1313076ea5ab75d15a35335468a9f6f269b1a42ca68ede844",
}
EXPECTED = {
    # Core anti-revoke / multi-open / browser.
    0x30C576C: "fc6fbda9f44f01a9fd7b02a9fd830091",
    0x4B62364: "60f9ff17f44fbea9fd7b01a9fd430091",
    0xAA4760: "f44fbea9fd7b01a9fd430091f30300aa",
    0x42E716C: "fc6fbda9f44f01a9fd7b02a9fd830091",
    0x26D5E8: "ff0306d1fc6f14a9f65715a9f44f16a9",
    0x21BC064: "ff8307d1fc6f1aa9f6571ba9f44f1ca9",
    # MessageData and native forwarding.
    0x4B654C0: "ffc301d1f85f03a9f65704a9f44f05a9",
    0x3830D4: "f44fbea9fd7b01a9fd430091f30300aa",
    0x1812DDC: "ff4306d1fc6f13a9fa6714a9f85f15a9",
    0x175E348: "ff8301d1f85f02a9f65703a9f44f04a9",
    0x4BFE874: "088802f008613a91084100911f700278",
    0x41F14C8: "f657bda9f44f01a9fd7b02a9fd830091",
    # Message menu.
    0xCBF7D0: "fc6fbaa9fa6701a9f85f02a9f65703a9",
    0x632CBC: "601240f9e8230091e1658995e00740f9",
    0x1E80774: "24ffff17f44fbea9fd7b01a9fd430091",
    0x1E7B89C: "ff4301d1f85f01a9f65702a9f44f03a9",
    0xCC2504: "ff4302d1fa6704a9f85f05a9f65706a9",
    0x685C0F0: "ffc300d1fd7b02a9fd830091688901d0",
    # Media paths, lookup, decoding and download task.
    0x476DE94: "ff8306d1fa6715a9f85f16a9f65717a9",
    0x4754194: "ffc300d1f44f01a9fd7b02a9fd830091",
    0x4519FC8: "ff4301d1f65702a9f44f03a9fd7b04a9",
    0x4508148: "ffc305d1fc6f13a9f65714a9f44f15a9",
    0x4A798CC: "fd7bbfa9fd030091c36495941f000071",
    0x4420090: "ffc307d1fa671aa9f85f1ba9f6571ca9",
    0x43EDF08: "ffc306d1fc6f16a9f85f17a9f65718a9",
    0x3E63A24: "f657bda9f44f01a9fd7b02a9fd830091",
    0x6500484: "ff8306d1f65717a9f44f18a9fd7b19a9",
    0x6500BA0: "080c059108fddf0800010012c0035fd6",
    # Native self-revoke retention, independent notice insertion and expiry refresh.
    0x3419BB8: "e08341f9e1e300910200805211eaf197",
    0x3419C78: "a00353f8e8030c91e1a3189163b1f297",
    0x3419E5C: "e1a31891e00313aa11d6d39728008052",
    0x3417E44: "a8835bf8892b03f0294546f9290140f9",
    0x341CC90: "937e40f9fc9341f9e89741f99f0308eb",
    0x341CE34: "e00314aa1f185d94817e40f9e8c30091",
    0x341D4A4: "e29740f9a86372a9e86301a9780000b4",
    0x4BD29B0: "fc6fbda9f44f01a9fd7b02a9fd830091",
    0x3418394: "f68741f9760100b4c822009109008092",
    0x30D0E50: "f85fbca9f65701a9f44f02a9fd7b03a9",
    0xF0B548: "f85fbca9f65701a9f44f02a9fd7b03a9",
    0x127BA0: "f44fbea9fd7b01a9fd430091130440f9",
    0x451A950: "ffc300d1f44f01a9fd7b02a9fd830091",
    0x11B809C: "0aa442a90a2500a9890000b428210091",
    0x25B6684: "ffc301d1f44f05a9fd7b06a9fd830191",
    0x2FB0D74: "fc6fbaa9fa6701a9f85f02a9f65703a9",
    0x451941C: "08ec02d000c544f9c0035fd6ffc300d1",
    0x4B62EB4: "f44fbea9fd7b01a9fd430091f30300aa",
    0x4B62FD8: "080c40b909e284521f01096b60050054",
    0x48DC10C: "ffc300d1f44f01a9fd7b02a9fd830091",
    0x341D7E8: "ff8305d1fc6f12a9f65713a9f44f14a9",
    0x3094408: "f85fbca9f65701a9f44f02a9fd7b03a9",
    0x30C6210: "ff4301d1f65702a9f44f03a9fd7b04a9",
    0x3419C88: "e0a31891e1030c919cddd397e0030c91",
    0x341CE48: "e0430b91e1c30091e2c30091e30314aa",
    0x3419E70: "e0a318913b2a5a97e8c34a391f050071",
    0x6FD1020: "d04d01b0101246f900021fd6d04d01b0",
    0x6FD07D4: "d04d01d0107a42f900021fd6d04d01d0",
    0x4BD2ADC: "fc6fbba9f85f01a9f65702a9f44f03a9",
    # Group-exit monitor.
    0x2A30E40: "fc6fbaa9fa6701a9f85f02a9f65703a9",
    0x2D60C8C: "fc6fbaa9fa6701a9f85f02a9f65703a9",
    0x41F42C8: "fc6fbaa9fa6701a9f85f02a9f65703a9",
    0x28C8764: "fc6fbaa9fa6701a9f85f02a9f65703a9",
    0x28EB3BC: "fc6fbba9f85f01a9f65702a9f44f03a9",
    # Group member display-name cache lookup.
    0x237ED18: "ff0301d1f44f02a9fd7b03a9fdc30091",
    0x43B2500: "ff0301d1f65701a9f44f02a9fd7b03a9",
    0x4AC9D88: "00800191a3dffc17f44fbea9fd7b01a9",
    0x43B5ED4: "f657bda9f44f01a9fd7b02a9fd830091",
    0x28FA314: "ff0301d1f65701a9f44f02a9fd7b03a9",
    0x29CD554: "e95f40f9a90000b421a10291e00313aa",
    # Navigation sidebar profile (all patched and called private ABI points).
    0x11C6708: "ffc302d1eb2b036de923046dfc6f05a9",
    0x11C6FE4: "ffc300d1f44f01a9fd7b02a9fd830091",
    0x11C7130: "ffc300d1f44f01a9fd7b02a9fd830091",
    0x11C7C80: "fc6fbaa9fa6701a9f85f02a9f65703a9",
    0x1CF22F8: "ffc305d1fc6f14a9f44f15a9fd7b16a9",
    0x11CA140: "00bc40f9181a3514ff8301d1f65703a9",
    0x109FAAC: "002840b9c0035fd62e09ca9a8f01098b",
    0x11CEF3C: "ff8306d1fc6f14a9fa6715a9f85f16a9",
    0x1F10A30: "f657bda9f44f01a9fd7b02a9fd830091",
    0x11CC37C: "f657bda9f44f01a9fd7b02a9fd830091",
    0x11CC490: "f657bda9f44f01a9fd7b02a9fd830091",
    0x1F11BC8: "ffc300d1f44f01a9fd7b02a9fd830091",
    0x1F11B00: "ffc300d1f44f01a9fd7b02a9fd830091",
    0x1AE8378: "002841f9400000b49cc8ff17c0035fd6",
    0x6D89F08: "ffc300d1f44f01a9fd7b02a9fd830091",
    0x4C8EA6C: "e89602b009cd42f9280140b91f710171",
    0x6D8D394: "ff8300d1fd7b01a9fd430091a9430091",
    0x6D333AC: "489a01b008e13a911f0008eb40000054",
    0x6898958: "ff0301d1f44f02a9fd7b03a9fdc30091",
    0x6894660: "000440f90100805267e3ff17f657bda9",
    0x1F10C80: "f657bda9f44f01a9fd7b02a9fd830091",
    0x1F11848: "f44fbea9fd7b01a9fd430091f30300aa",
    0x1F11AD8: "f44fbea9fd7b01a9fd430091f30300aa",
}

ENTRY_PATTERN = re.compile(
    r"\b(0x[0-9a-fA-F]+)\s*,\s*\{\s*((?:0x[0-9a-fA-F]{1,2}\s*,?\s*){16})\}",
    re.DOTALL,
)
MAPPING_PATTERN = re.compile(
    r"case\s+(0x[0-9a-fA-F]+)\s*:\s*return\s+YMRuntimeAddress\((0x[0-9a-fA-F]+)\)\s*;"
)


def arm64_slice(data: bytes) -> bytes:
    if len(data) < 4:
        raise ValueError("binary is truncated")
    if data[:4] in OTHER_FAT_MAGICS:
        raise ValueError("unsupported universal binary format")
    if data[:4] != FAT_MAGIC:
        return data

    if len(data) < 8:
        raise ValueError("universal binary header is truncated")
    count = struct.unpack_from(">I", data, 4)[0]
    if count == 0:
        raise ValueError("universal binary has no slices")

    table_end = 8 + count * 20
    if table_end > len(data):
        raise ValueError("universal binary slice table is truncated")

    arm_slices: list[tuple[int, int, int]] = []
    ranges: list[tuple[int, int]] = []
    for index in range(count):
        cpu, subtype, offset, size, alignment = struct.unpack_from(">iiIII", data, 8 + index * 20)
        if size == 0 or offset < table_end or offset > len(data) - size:
            raise ValueError(f"universal binary slice {index} is out of bounds")
        if alignment > 31 or offset % (1 << alignment) != 0:
            raise ValueError(f"universal binary slice {index} has invalid alignment")
        ranges.append((offset, offset + size))
        if cpu == ARM64:
            arm_slices.append((subtype, offset, size))

    sorted_ranges = sorted(ranges)
    for index, current in enumerate(sorted_ranges[1:], start=1):
        if current[0] < sorted_ranges[index - 1][1]:
            raise ValueError("universal binary slices overlap")

    if len(arm_slices) != 1:
        raise ValueError(f"universal binary must contain exactly one arm64 slice, found {len(arm_slices)}")
    subtype, offset, size = arm_slices[0]
    if subtype != ARM64_ALL:
        raise ValueError(f"unexpected arm64 CPU subtype: {subtype}")
    return data[offset:offset + size]


def macho_uuid(data: bytes) -> bytes:
    if len(data) < 32 or struct.unpack_from("<I", data)[0] != 0xFEEDFACF:
        raise ValueError("arm64 slice is not a 64-bit little-endian Mach-O")
    cpu, subtype = struct.unpack_from("<ii", data, 4)
    if cpu != ARM64 or subtype != ARM64_ALL:
        raise ValueError("thin Mach-O is not arm64-all")
    command_count, command_bytes = struct.unpack_from("<II", data, 16)
    if command_bytes > len(data) - 32 or command_count > command_bytes // 8:
        raise ValueError("Mach-O load command table is out of bounds")
    cursor, end = 32, 32 + command_bytes
    uuids: list[bytes] = []
    for _ in range(command_count):
        if cursor + 8 > end:
            raise ValueError("Mach-O load command header is truncated")
        command, size = struct.unpack_from("<II", data, cursor)
        if size < 8 or cursor + size > end:
            raise ValueError("invalid Mach-O load commands")
        if command == 0x1B:
            if size < 24:
                raise ValueError("Mach-O UUID command is truncated")
            uuids.append(data[cursor + 8:cursor + 24])
        cursor += size
    if cursor != end:
        raise ValueError("Mach-O load command byte count mismatch")
    if len(uuids) != 1:
        raise ValueError(f"Mach-O must contain exactly one UUID, found {len(uuids)}")
    return uuids[0]


def verify_source_file_hashes() -> None:
    for name, expected in EXPECTED_SOURCE_FILE_SHA256.items():
        path = SOURCE_DIR / name
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f"source file SHA-256 mismatch: {name}")


def source_section(path: Path, start_marker: str, end_marker: str) -> str:
    text = path.read_text(encoding="utf-8")
    start = text.find(start_marker)
    if start < 0:
        raise ValueError(f"source marker missing in {path.name}: {start_marker}")
    end = text.find(end_marker, start + len(start_marker))
    if end < 0:
        raise ValueError(f"source marker missing in {path.name}: {end_marker}")
    return text[start:end]


def parse_fingerprints(section: str) -> list[tuple[int, bytes]]:
    result = []
    for match in ENTRY_PATTERN.finditer(section):
        payload = bytes(int(value, 16) for value in re.findall(r"0x([0-9a-fA-F]{1,2})", match.group(2)))
        if len(payload) != 16:
            raise ValueError(f"invalid source fingerprint at {match.group(1)}")
        result.append((int(match.group(1), 16), payload))
    return result


def source_fingerprints() -> dict[str, list[tuple[int, bytes]]]:
    return {
        "self": parse_fingerprints(source_section(
            SOURCE_DIR / "SelfRevokePatch.mm",
            "const Fingerprint fingerprints270102[] = {",
            "\n};",
        )),
        "menu": parse_fingerprints(source_section(
            SOURCE_DIR / "MessageMenuPatch.mm",
            "static const Entry entries270102[] = {",
            "\n    };",
        )),
        "media": parse_fingerprints(source_section(
            SOURCE_DIR / "MessageMediaActions.mm",
            "if (YMMessageMedia270102) {",
            "\n    } else {",
        )),
        "sidebar": parse_fingerprints(source_section(
            SOURCE_DIR / "SidebarRuntime.h",
            "YMNavigationSidebarWeChat415BuildProfile = {",
            "\n        };\n\nstatic constexpr std::size_t kYMNavigationSidebarBuildProfileTargetCount",
        )),
    }


def source_mappings() -> dict[str, list[tuple[int, int]]]:
    sections = {
        "menu": source_section(
            SOURCE_DIR / "MessageMenuPatch.mm",
            "static uintptr_t YMMessageMenuAddress",
            "\n}\n\nYMMessageSnapshot::YMMessageSnapshot",
        ),
        "media": source_section(
            SOURCE_DIR / "MessageMediaActions.mm",
            "static uintptr_t YMMessageMediaAddress",
            "\n}\n\n#define YMRuntimeAddress",
        ),
    }
    return {
        group: [(int(old, 16), int(new, 16)) for old, new in MAPPING_PATTERN.findall(section)]
        for group, section in sections.items()
    }


def verify_source_profiles(data: bytes) -> tuple[int, int, int]:
    verify_source_file_hashes()
    groups = source_fingerprints()
    expected_counts = {"self": 30, "menu": 23, "media": 24, "sidebar": 24}
    actual_counts = {group: len(entries) for group, entries in groups.items()}
    if actual_counts != expected_counts:
        raise ValueError(f"source fingerprint counts mismatch: {actual_counts}")

    records = [
        f"{group}:{address:x}:{payload.hex()}"
        for group in ("self", "menu", "media", "sidebar")
        for address, payload in groups[group]
    ]
    digest = hashlib.sha256("\n".join(records).encode()).hexdigest()
    if digest != EXPECTED_SOURCE_FINGERPRINT_DIGEST:
        raise ValueError("source fingerprint manifest mismatch")

    source_unique: dict[int, bytes] = {}
    for group in ("self", "menu", "media", "sidebar"):
        for address, payload in groups[group]:
            previous = source_unique.setdefault(address, payload)
            if previous != payload:
                raise ValueError(f"conflicting source fingerprints at 0x{address:x}")
            if data[address:address + len(payload)] != payload:
                raise ValueError(f"source fingerprint mismatch at 0x{address:x}")

    if len(records) != 101 or len(source_unique) != 97:
        raise ValueError("source fingerprint coverage mismatch")

    mappings = source_mappings()
    if {group: len(entries) for group, entries in mappings.items()} != {"menu": 19, "media": 32}:
        raise ValueError("source mapping counts mismatch")
    mapping_records = [
        f"{group}:{old:x}:{new:x}"
        for group in ("menu", "media")
        for old, new in mappings[group]
    ]
    mapping_digest = hashlib.sha256("\n".join(mapping_records).encode()).hexdigest()
    if mapping_digest != EXPECTED_MAPPING_DIGEST:
        raise ValueError("source mapping manifest mismatch")

    all_unique = set(source_unique) | set(EXPECTED)
    if len(all_unique) != 119:
        raise ValueError(f"combined fingerprint coverage mismatch: {len(all_unique)}")
    return len(records), len(all_unique), len(mapping_records)


def verify(path: Path) -> tuple[int, int, int]:
    raw = path.read_bytes()
    is_fat = raw[:4] == FAT_MAGIC
    data = arm64_slice(raw)
    if is_fat and hashlib.sha256(raw).hexdigest() != EXPECTED_FAT_SHA256:
        raise ValueError("fat SHA-256 mismatch")
    if hashlib.sha256(data).hexdigest() != EXPECTED_SHA256:
        raise ValueError("arm64 SHA-256 mismatch")
    if macho_uuid(data) != EXPECTED_UUID:
        raise ValueError("Mach-O UUID mismatch")
    for address, expected_hex in EXPECTED.items():
        expected = bytes.fromhex(expected_hex)
        if data[address:address + len(expected)] != expected:
            raise ValueError(f"fingerprint mismatch at 0x{address:x}")
    return verify_source_profiles(data)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {Path(sys.argv[0]).name} /path/to/Resources/wechat.dylib")
    source_count, unique_count, mapping_count = verify(Path(sys.argv[1]))
    print(
        "WeChat 4.1.15 / 270102 arm64 profile: OK "
        f"({source_count} source fingerprints, {unique_count} unique checks, {mapping_count} mappings)"
    )
