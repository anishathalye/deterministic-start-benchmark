#!/usr/bin/env python3

import time
import subprocess

OUT = 'bench-racket.txt'

with open(OUT, 'w') as fout:
    for cycles in range(105):
        prog = 'verify-cycles-%03d.rkt' % cycles
        subprocess.check_call(['raco', 'make', prog])
        start = time.time()
        subprocess.check_call(['racket', prog])
        end = time.time()
        dur = end - start
        fout.write('%d %.3f\n' % (cycles, dur))
        fout.flush()
