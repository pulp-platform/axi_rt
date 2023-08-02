# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
# Licensed under Solderpad Hardware License, Version 0.51, see LICENSE for details.
#
# Authors:
# - Thomas Benz <tbenz@iis.ee.ethz.ch>

import sys
import random


_, num_transactions, min_len, max_len, is_write, seed = sys.argv

AX_TEMPLATE = '''{id}\n{addr}\n{len}\n{size}\n{burst}\n{lock}\n{cache}\n{prot}\n{qos}\n{region}\n{atop}{user}\n'''
W_TEMPLATE  = '''{data} {strb} {user}\n'''

def gen_rand_hex (num_bytes : int) -> str:
    ret = '0x'
    for b in range(0, num_bytes):
        ret += str(hex(random.randint(0, 15)))[2:]
    return ret

random.seed(seed)

for n in range(0, int(num_transactions)):
    if int(is_write):
        atop_entry = '0\n'
    else:
        atop_entry = ''

    len_beats = random.randint(int(min_len), int(max_len))

    ax = {
        'id'     : '0',
        'addr'   : str(hex(0x100 + 64*n)),
        'len'    : len_beats,
        'size'   : '2',
        'burst'  : '1',
        'lock'   : '0',
        'cache'  : '2',
        'prot'   : '0',
        'qos'    : '0',
        'region' : '0',
        'atop'   : atop_entry,
        'user'   : '0'
        }
    print(AX_TEMPLATE.format(**ax), end='')

    if int(is_write):
        for b in range(0, int(len_beats) + 1):

            w = {
                'data' : gen_rand_hex(8),
                'strb' : gen_rand_hex(2),
                'user' :  '0'
                }
            print(W_TEMPLATE.format(**w), end='')

