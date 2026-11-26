"""T-0040 Verifier: pure-Python PNG pixel diff (8-bit RGB/RGBA, non-interlaced).
Usage: pngdiff.py before.png after.png
Prints size, number of differing pixels, the bounding box of the diff, and
row bands that differ."""
import struct
import sys
import zlib


def decode(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    pos, idat, w = 8, b'', None
    while pos < len(data):
        n, = struct.unpack('>I', data[pos:pos + 4])
        typ = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if typ == b'IHDR':
            w, h, depth, ctype, _, _, inter = struct.unpack('>IIBBBBB', body)
            assert depth == 8 and inter == 0, (depth, inter)
            bpp = {2: 3, 6: 4, 0: 1, 4: 2}[ctype]
        elif typ == b'IDAT':
            idat += body
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(bytes(line))
        prev = line
    return w, h, bpp, rows


def main():
    w1, h1, b1, r1 = decode(sys.argv[1])
    w2, h2, b2, r2 = decode(sys.argv[2])
    print(f'size before {w1}x{h1} after {w2}x{h2}')
    if (w1, h1, b1) != (w2, h2, b2):
        print('DIFFERENT GEOMETRY')
        return
    n, xs, ys, bands = 0, [], [], []
    for y in range(h1):
        if r1[y] == r2[y]:
            continue
        for x in range(w1):
            if r1[y][x * b1:(x + 1) * b1] != r2[y][x * b1:(x + 1) * b1]:
                n += 1
                xs.append(x)
                ys.append(y)
        if not bands or bands[-1][1] != y - 1:
            bands.append([y, y])
        else:
            bands[-1][1] = y
    if n == 0:
        print('identical pixels')
        return
    print(f'diff pixels {n}; bbox x {min(xs)}..{max(xs)} y {min(ys)}..{max(ys)}; row bands {bands}')


main()
