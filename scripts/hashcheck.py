# cat examples/*.forth | python3 scripts/hashcheck.py

from ctypes import c_uint32
import fileinput

FLAGS_MASK = 0xc0000000


def tpop_hash(s):
    h = 0
    for c in s:
        h = 37 * h + ord(c)
        h = c_uint32(h).value & ~FLAGS_MASK
    return h


def perl_hash(s):
    h = 0
    for c in s:
        h = 33 * h + ord(c)
        h = h + (h >> 5)
        h = c_uint32(h).value & ~FLAGS_MASK
    return h


def word_size(s):
    padding = 4 - (len(s) % 4)
    if padding == 4:
        return len(s)
    else:
        return len(s) + padding


def cli_main():
    hashes = {}
    for line in fileinput.input():
        line = line.strip()
        if not line.startswith(':'):
            continue

        name = line.split()[1]

        h = tpop_hash(name)
        #h = perl_hash(name)
        if h in hashes and name != hashes[h]:
            print('COLLISION of {} and {}: {}'.format(name, hashes[h], h))
        else:
            hashes[h] = name

    without_hash = sum(word_size(name) for name in hashes.values())
    with_hash = 4 * len(hashes)
    savings = without_hash - with_hash
    print('TPOP hashing would save {} bytes'.format(savings))


if __name__ == '__main__':
    cli_main()
