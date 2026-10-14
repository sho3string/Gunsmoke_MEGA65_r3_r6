#!/usr/bin/env python3
"""Build all seven Gun.Smoke MEGA65 ROMs directly from the original MAME ZIP."""
import argparse
from pathlib import Path
import zipfile
import zlib


def sort_graphics(data, mask, high_bit, shift):
    out = bytearray(len(data))
    for src in range(len(data)):
        dst = (src & ~mask) | ((src & high_bit) >> shift) | ((src & (mask ^ high_bit)) << 1)
        out[dst] = data[src]
    return bytes(out)


def interleave(a, b):
    if len(a) != len(b):
        raise ValueError('Interleaved chips have different sizes')
    out = bytearray(len(a) * 2)
    out[0::2], out[1::2] = a, b
    return bytes(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mame_zip', type=Path, help='Original GUNSMOKE.ZIP MAME archive')
    parser.add_argument('-o', '--output', type=Path, default=Path('arcade/gunsmoke'))
    args = parser.parse_args()

    with zipfile.ZipFile(args.mame_zip) as archive:
        def chip(name, size):
            data = archive.read(name)
            if len(data) != size:
                raise ValueError(f'{name}: expected {size} bytes, got {len(data)}')
            return data

        roms = {}
        roms['main'] = b''.join(chip(n, 32768) for n in (
            '09n_gs03.bin', '10n_gs04.bin', '12n_gs05.bin'))
        roms['sound'] = chip('14h_gs02.bin', 32768)
        char = chip('11f_gs01.bin', 16384)
        roms['char'] = b''.join(char[i:i+2][::-1] for i in range(0, len(char), 2))
        map_chip = chip('11c_gs14.bin', 32768)
        map_swapped = b''.join(map_chip[i:i+2][::-1] for i in range(0, len(map_chip), 2))
        roms['map'] = sort_graphics(map_swapped, 0x1e, 0x10, 3)
        roms['scr'] = b''.join(interleave(chip(f'{n}a_gs{a}.bin', 32768),
                                            chip(f'{n}c_gs{c}.bin', 32768))
                               for n, a, c in (('06', '09', '13'), ('05', '08', '12'),
                                               ('04', '07', '11'), ('02', '06', '10')))
        obj = b''.join(interleave(chip(e, 32768), chip(o, 32768)) for e, o in (
            ('06l_gs18.bin', '06n_gs22.bin'),
            ('04l_gs17.bin', '04n_gs21.bin'),
            ('03l_gs16.bin', '03n_gs20.bin'),
            ('01l_gs15.bin', '01n_gs19.bin')))
        roms['obj'] = sort_graphics(obj, 0x7c, 0x40, 4)
        roms['prom'] = b''.join(chip(n, 256) for n in (
            '03b_g-01.bin', '04b_g-02.bin', '05b_g-03.bin', '09d_g-04.bin',
            '14a_g-06.bin', '15a_g-07.bin', '09f_g-09.bin', '08f_g-08.bin',
            '02j_g-10.bin', '01f_g-05.bin'))

    args.output.mkdir(parents=True, exist_ok=True)
    for part in ('main', 'sound', 'char', 'map', 'scr', 'obj', 'prom'):
        data = roms[part]
        name = f'gunsmoke_{part}.rom'
        (args.output / name).write_bytes(data)
        print(f'{name:24} {len(data):7} bytes  CRC32 {zlib.crc32(data):08X}')
    print(f'\nROMs written to: {args.output}')


if __name__ == '__main__':
    main()
