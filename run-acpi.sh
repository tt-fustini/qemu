#!/bin/bash
export LX=$HOME/dev/linux
export BR=$HOME/dev/images        
export EDK=$HOME/dev/edk2
build/qemu-system-riscv64 \
	-M virt,pflash0=pflash0,pflash1=pflash1,aia=aplic-imsic  \
	-nographic \
	-m 1G -smp 2  -serial mon:stdio \
	-kernel ${LX}/arch/riscv/boot/Image \
	-append "root=/dev/vda ro loglevel=8 ro console=ttyS0 rootwait earlycon=uart8250,mmio,0x10000000" \
	-blockdev node-name=pflash0,driver=file,read-only=on,filename=$EDK/RISCV_VIRT_CODE.fd \
	-blockdev node-name=pflash1,driver=file,filename=$EDK/RISCV_VIRT_VARS.fd \
	-drive if=none,file=${BR}/rootfs.ext2,format=raw,id=hd0 \
	-device virtio-blk-device,drive=hd0 \
	-device qemu-xhci \
	-device usb-kbd \
	-device virtio-net-pci,netdev=net0 \
	-netdev user,id=net0 \
	-device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=12,alloc_op_flush_rcid=false,mon_op_config_event=false,mon_op_read_counter=false,mon_evt_id_none=false,mon_evt_id_occupancy=false,mmio_base=0x04820000 \
	-device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=12,alloc_op_flush_rcid=false,mon_op_config_event=false,mon_op_read_counter=false,mon_evt_id_none=false,mon_evt_id_occupancy=false,mmio_base=0x04821000 \
	-device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=16,mmio_base=0x0482B000 \
	-device riscv.cbqri.bandwidth,max_mcids=256,max_rcids=64,nbwblks=1024,mrbwb=819,mmio_base=0x04828000 \
	-device riscv.cbqri.bandwidth,max_mcids=256,max_rcids=64,nbwblks=1024,mrbwb=819,mmio_base=0x04829000 \
	-device riscv.cbqri.bandwidth,max_mcids=256,max_rcids=64,nbwblks=1024,mrbwb=819,mmio_base=0x0482a000
