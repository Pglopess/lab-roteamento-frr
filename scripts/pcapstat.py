#!/usr/bin/env python3
# Uso: pcapstat.py arq1.pcap arq2.pcap ...  -> imprime "pacotes bytes"
import struct, sys
pk = by = 0
for f in sys.argv[1:]:
    d = open(f, 'rb').read()
    if len(d) < 24: continue
    e = '<' if d[:4] in (b'\xd4\xc3\xb2\xa1', b'\x4d\x3c\xb2\xa1') else '>'
    o = 24
    while o + 16 <= len(d):
        _, _, incl, orig = struct.unpack(e + 'IIII', d[o:o+16])
        pk += 1; by += orig; o += 16 + incl
print(pk, by)
