#!/usr/bin/env python3
"""Verify the exact arm64 Resources/wechat.dylib used by the 270102 profile."""

import hashlib
import struct
import sys
from pathlib import Path


ARM64 = 0x0100000C
EXPECTED_SHA256 = "07e35c5d8ea0d97f1f16d79a5efec42fa1ca97213f634d473631beeaae8f0841"
EXPECTED_UUID = bytes.fromhex("3b7b6abb2c363e58a384cdef05a57aa5")
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


def arm64_slice(data: bytes) -> bytes:
    if data[:4] != b"\xca\xfe\xba\xbe":
        return data
    count = struct.unpack_from(">I", data, 4)[0]
    for index in range(count):
        cpu, _, offset, size, _ = struct.unpack_from(">iiIII", data, 8 + index * 20)
        if cpu == ARM64:
            return data[offset:offset + size]
    raise ValueError("universal binary has no arm64 slice")


def macho_uuid(data: bytes) -> bytes:
    if len(data) < 32 or struct.unpack_from("<I", data)[0] != 0xFEEDFACF:
        raise ValueError("arm64 slice is not a 64-bit little-endian Mach-O")
    command_count, command_bytes = struct.unpack_from("<II", data, 16)
    cursor, end = 32, 32 + command_bytes
    for _ in range(command_count):
        command, size = struct.unpack_from("<II", data, cursor)
        if size < 8 or cursor + size > end:
            raise ValueError("invalid Mach-O load commands")
        if command == 0x1B:
            return data[cursor + 8:cursor + 24]
        cursor += size
    raise ValueError("Mach-O UUID is missing")


def verify(path: Path) -> None:
    data = arm64_slice(path.read_bytes())
    assert hashlib.sha256(data).hexdigest() == EXPECTED_SHA256, "arm64 SHA-256 mismatch"
    assert macho_uuid(data) == EXPECTED_UUID, "Mach-O UUID mismatch"
    for address, expected_hex in EXPECTED.items():
        expected = bytes.fromhex(expected_hex)
        assert data[address:address + len(expected)] == expected, f"fingerprint mismatch at 0x{address:x}"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {Path(sys.argv[0]).name} /path/to/Resources/wechat.dylib")
    verify(Path(sys.argv[1]))
    print("WeChat 4.1.15 / 270102 arm64 profile: OK")
