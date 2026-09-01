#!/bin/bash
# DT-mode launcher: boot virt with a single CBQRI capacity controller backing
# a shared L3, described entirely in the QEMU-generated device tree (no ACPI,
# no EDK2). The controller has 8 capacity blocks, so resctrl reports a default
# capacity bitmask of 0xff. Pairs with the kernel branch
# dfustini/atl-sc-cbqri-dt built with CONFIG_RISCV_CBQRI_CAPACITY=y.
#
# Counterpart to run-dt-1cc.sh, which backs the shared L2 with 16 blocks.
set -e
export LX=$HOME/dev/linux
export BR=$HOME/dev/buildroot/output/images
export QEMU=$HOME/dev/qemu/build/qemu-system-riscv64

rm -f /tmp/qemu-dt.pid /tmp/qemu-dt.sock /tmp/qemu-dt.log

$QEMU \
    -M virt,aia=aplic-imsic \
    -nographic \
    -m 1G \
    -smp 8 \
    -kernel ${LX}/arch/riscv/boot/Image \
    -append "root=/dev/vda ro console=ttyS0 rootwait earlycon" \
    -drive if=none,file=${BR}/rootfs.ext2,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=8,cache_level=3,mmio_base=0x04820000
