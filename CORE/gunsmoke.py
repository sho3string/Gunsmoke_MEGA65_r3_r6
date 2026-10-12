#!/usr/bin/env python3
"""Build Gun.Smoke MEGA65 ROMs, sorting object (hvvvvxx) and map (hvvvx) graphics.

Usage: python3 gunsmoke.py GUNSMOKE.ZIP gunsmoke_meg65_roms.zip

The second ZIP supplies the existing prepared MEGA65 ROMs.
The object ROM is reconstructed from the eight original MAME chips and sorted.
The map ROM is sorted from the prepared map; the other five ROMs are unchanged.
"""
import argparse
from pathlib import Path
import zipfile
import zlib

OBJECT_PAIRS = (
    ("06l_gs18.bin", "06n_gs22.bin"),
    ("04l_gs17.bin", "04n_gs21.bin"),
    ("03l_gs16.bin", "03n_gs20.bin"),
    ("01l_gs15.bin", "01n_gs19.bin"),
)
OTHER_ROMS = (
    "gunsmoke_main.rom", "gunsmoke_sound.rom", "gunsmoke_char.rom",
    "gunsmoke_scr.rom", "gunsmoke_prom.rom",
)

def build_object(mame):
    out = bytearray()
    for even_name, odd_name in OBJECT_PAIRS:
        even, odd = mame.read(even_name), mame.read(odd_name)
        if len(even) != 32768 or len(odd) != 32768:
            raise ValueError(f"Incorrect object chip size: {even_name} / {odd_name}")
        block = bytearray(65536)
        block[0::2] = even
        block[1::2] = odd
        out.extend(block)
    return bytes(out)

def gfx_sort_hvvvvxx(data):
    if len(data) % 128:
        raise ValueError("Object ROM size must be a multiple of 128 bytes")
    out = bytearray(len(data))
    for src in range(len(data)):
        # Move source A6 to destination A2; source A2..A5 to A3..A6.
        dst = (src & ~0x7c) | ((src & 0x40) >> 4) | ((src & 0x3c) << 1)
        out[dst] = data[src]
    return bytes(out)

def gfx_sort_hvvvx(data):
    if len(data) % 32:
        raise ValueError("Map ROM size must be a multiple of 32 bytes")
    out = bytearray(len(data))
    for src in range(len(data)):
        # Move source A4 to destination A1; source A1..A3 to A2..A4.
        dst = (src & ~0x1e) | ((src & 0x10) >> 3) | ((src & 0x0e) << 1)
        out[dst] = data[src]
    return bytes(out)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mame_zip", type=Path)
    parser.add_argument("prepared_zip", type=Path)
    parser.add_argument("--output", type=Path, default=Path("arcade/gunsmoke"))
    args = parser.parse_args()
    with zipfile.ZipFile(args.mame_zip) as mame, zipfile.ZipFile(args.prepared_zip) as prepared:
        obj = gfx_sort_hvvvvxx(build_object(mame))
        map_rom = gfx_sort_hvvvx(prepared.read("gunsmoke_map.rom"))
        args.output.mkdir(parents=True, exist_ok=True)
        for name in OTHER_ROMS:
            data = prepared.read(name)
            (args.output / name).write_bytes(data)
            print(f"{name:24} {len(data):7} bytes  CRC32 {zlib.crc32(data):08X}")
        (args.output / "gunsmoke_map.rom").write_bytes(map_rom)
        print(f"{'gunsmoke_map.rom':24} {len(map_rom):7} bytes  CRC32 {zlib.crc32(map_rom):08X}  (hvvvx sorted)")
        (args.output / "gunsmoke_obj.rom").write_bytes(obj)
        print(f"{'gunsmoke_obj.rom':24} {len(obj):7} bytes  CRC32 {zlib.crc32(obj):08X}  (hvvvvxx sorted)")

if __name__ == "__main__":
    main()
