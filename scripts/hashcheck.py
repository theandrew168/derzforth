from ctypes import c_uint32
import fileinput


def tpop_hash(s):
    h = 0
    for c in s:
        h = 37 * h + ord(c)
        h = c_uint32(h).value
    return h


hashes = {}
for line in fileinput.input():
    line = line.strip()
    if not line.startswith(':'):
        continue

    name = line.split()[1]

    h = tpop_hash(name)
    if h in hashes and name != hashes[h]:
        print('COLLISION of {} and {}: {}'.format(name, hashes[h], h))
    else:
        hashes[h] = name
