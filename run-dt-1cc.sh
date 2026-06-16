#!/bin/bash
# DT-mode launcher: boot virt with a single CBQRI capacity controller backing
# a shared L2, described entirely in the QEMU-generated device tree (no ACPI,
# no EDK2). Pairs with the kernel branch dfustini/atl-sc-cbqri-dt built with
# CONFIG_RISCV_CBQRI_CAPACITY=y.
set -e
export LX=$HOME/dev/linux
export BR=$HOME/dev/buildroot/output/images
export QEMU=$HOME/dev/qemu/build/qemu-system-riscv64

rm -f /tmp/qemu-dt.pid /tmp/qemu-dt.sock /tmp/qemu-dt.log

$QEMU \
    -M virt,aia=aplic-imsic \
    -nographic \
    -m 1G \
    -smp cpus=8,sockets=1,clusters=2,cores=4,threads=1 \
    -kernel ${LX}/arch/riscv/boot/Image \
    -append "root=/dev/vda ro loglevel=8 console=ttyS0 rootwait earlycon=uart8250,mmio,0x10000000" \
    -drive if=none,file=${BR}/rootfs.ext2,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=16,mmio_base=0x04820000
