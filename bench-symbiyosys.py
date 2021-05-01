#!/usr/bin/env python3

import time
import subprocess

OUT = 'bench-symbiyosys.txt'

with open(OUT, 'w') as fout:
    for cycles in range(105):
        prog = 'verify_cycles_%03d.sby' % cycles
        start = time.time()
        subprocess.check_call(['sby', '-f', prog])
        end = time.time()
        dur = end - start
        fout.write('%d %.3f\n' % (cycles, dur))
        fout.flush()
