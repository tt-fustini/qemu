#!/bin/bash

./configure --target-list=riscv64-softmmu  --enable-slirp --extra-cflags="-U __OPTIMIZE__"
make -j16

