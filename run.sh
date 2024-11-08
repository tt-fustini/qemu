export LX=/home/dfustini/data/linux
export BR=/home/dfustini/data/buildroot        
build/qemu-system-riscv64 \
        -M virt \
        -nographic \
        -smp 8 \
        -kernel ${LX}/arch/riscv/boot/Image \
        -dtb ${LX}/arch/riscv/boot/dts/qemu/qemu-virt-cbqri.dtb \
        -append "root=/dev/vda ro" \
        -drive file=${BR}/output/images/rootfs.ext2,format=raw,id=hd0 \
        -device virtio-blk-device,drive=hd0 \
        -device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=12,alloc_op_flush_rcid=false,mon_op_config_event=false,mon_op_read_counter=false,mon_evt_id_none=false,mon_evt_id_occupancy=false,mmio_base=0x04820000 \
        -device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=12,alloc_op_flush_rcid=false,mon_op_config_event=false,mon_op_read_counter=false,mon_evt_id_none=false,mon_evt_id_occupancy=false,mmio_base=0x04821000 \
        -device riscv.cbqri.capacity,max_mcids=256,max_rcids=64,ncblks=16,mmio_base=0x0482B000 \
        -device riscv.cbqri.bandwidth,max_mcids=256,max_rcids=64,nbwblks=1024,mrbwb=819,mmio_base=0x04828000 \
        -device riscv.cbqri.bandwidth,max_mcids=256,max_rcids=64,nbwblks=1024,mrbwb=819,mmio_base=0x04829000 \
        -device riscv.cbqri.bandwidth,max_mcids=256,max_rcids=64,nbwblks=1024,mrbwb=819,mmio_base=0x0482a000
