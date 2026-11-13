#!/usr/bin/env python3
# sdat2img (v4 transfer lists): transfer.list + new.dat -> raw image
import sys
tl, nd, out = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(tl).read().splitlines()
version, new_blocks = int(lines[0]), int(lines[1])
commands = lines[4:]
assert version >= 1, version
with open(out, 'wb') as f, open(nd, 'rb') as src:
    done = 0
    for line in commands:
        if not line.strip():
            continue
        parts = line.split(' ', 1)
        op = parts[0]
        nums = [int(x) for x in parts[1].split(',')] if len(parts) > 1 else []
        if op == 'new':
            count = nums[0]
            for i in range(1, count + 1, 2):
                begin, end = nums[i], nums[i + 1]
                f.seek(begin * 4096)
                remaining = end - begin
                while remaining > 0:
                    chunk = min(remaining, 1024)
                    data = src.read(chunk * 4096)
                    if not data:
                        break
                    f.write(data)
                    remaining -= chunk
                done += end - begin
        elif op == 'zero':
            count = nums[0]
            for i in range(1, count + 1, 2):
                begin, end = nums[i], nums[i + 1]
                f.seek(begin * 4096)
                f.write(b'\0' * ((end - begin) * 4096))
        elif op == 'erase':
            pass
print('new blocks written:', done, '(expect', new_blocks, ')')
