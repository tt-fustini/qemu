#!/bin/bash
# Single-BC variant of run-acpi.sh for automated resctrl testing.
# SoC config: 3 capacity controllers (2x L2 + 1x L3) + 1 bandwidth controller.
# The single BC pairs with L3 to expose mbm_total_bytes (MBM_TOTAL works).
set -e
export LX=$HOME/dev/linux
export BR=$HOME/dev/buildroot/output/images
export EDK=$HOME/dev/edk2
export QEMU=$HOME/dev/qemu/build/qemu-system-riscv64

rm -f /tmp/qemu-acpi.pid /tmp/qemu-acpi.sock /tmp/qemu-acpi.log

$QEMU \
    -M virt,pflash0=pflash0,pflash1=pflash1,aia=aplic-imsic \
    -display none -daemonize -pidfile /tmp/qemu-acpi.pid \
    -m 1G \
    -smp cpus=8,sockets=1,clusters=2,cores=4,threads=1 \
    -chardev socket,id=ser0,path=/tmp/qemu-acpi.sock,server=on,wait=off,logfile=/tmp/qemu-acpi.log \
    -serial chardev:ser0 \
    -kernel ${LX}/arch/riscv/boot/Image \
    -append "root=/dev/vda ro loglevel=8 console=ttyS0 rootwait earlycon=uart8250,mmio,0x10000000" \
    -blockdev node-name=pflash0,driver=file,read-only=on,filename=$EDK/RISCV_VIRT_CODE.fd \
    -blockdev node-name=pflash1,driver=file,filename=$EDK/RISCV_VIRT_VARS.fd \
    -drive if=none,file=${BR}/rootfs.ext2,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -device qemu-xhci -device usb-kbd \
    -device virtio-net-pci,netdev=net0 -netdev user,id=net0 \
    -device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=12,alloc_op_flush_rcid=false,mon_op_config_event=false,mon_op_read_counter=false,mon_evt_id_none=false,mon_evt_id_occupancy=false,mmio_base=0x04820000 \
    -device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=12,alloc_op_flush_rcid=false,mon_op_config_event=false,mon_op_read_counter=false,mon_evt_id_none=false,mon_evt_id_occupancy=false,mmio_base=0x04821000 \
    -device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=16,mmio_base=0x0482B000 \
    -device riscv.cbqri.bandwidth,max_mcids=256,max_rcids=64,nbwblks=1024,mrbwb=819,mmio_base=0x04828000

echo "QEMU pid: $(cat /tmp/qemu-acpi.pid)"
echo "Socket:   /tmp/qemu-acpi.sock"
