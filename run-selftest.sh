#!/bin/bash
# Run the resctrl CBQRI selftest inside the RISC-V QEMU guest.
#
# Usage:
#   ./run-selftest.sh              # default: -t RBWB,MWEIGHT
#   ./run-selftest.sh -t RBWB      # any resctrl_tests args are passed through
#   ./run-selftest.sh --shutdown   # stop the QEMU instance this script manages
#
# Requirements: qemu-system-riscv64, edk2 firmware, buildroot rootfs,
# riscv64-linux-gnu-gcc, debugfs, socat, python3.

set -eu

LX=${LX:-/home/pdp7/dev/linux/.worktrees/cbqri-bw-schemata}
BR=${BR:-/home/pdp7/dev/buildroot/output/images}
EDK=${EDK:-/home/pdp7/dev/edk2}
QEMU=${QEMU:-/home/pdp7/dev/qemu/build/qemu-system-riscv64}

PID_FILE=/tmp/qemu-selftest.pid
SOCK=/tmp/qemu-selftest.sock
BOOT_LOG=/tmp/qemu-selftest-boot.log
HTTP_PORT=8765

SELFTEST_DIR=$LX/tools/testing/selftests/resctrl
SELFTEST_BIN=$SELFTEST_DIR/resctrl_tests

BOOT_TIMEOUT=120
TEST_TIMEOUT=120

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

# Send commands to the QEMU guest shell via the unix socket.  First arg is a
# heredoc of shell commands; they are fed to socat along with sleeps between
# them so the guest has time to process each line before EOF closes the
# connection.
send() {
	local wait_sec=${1:-5}
	shift
	{
		sleep 1
		while IFS= read -r line; do
			printf '%s\n' "$line"
			sleep 1
		done
		sleep "$wait_sec"
	} | socat - UNIX-CONNECT:"$SOCK"
}

shutdown_qemu() {
	if [ -f "$PID_FILE" ]; then
		local pid
		pid=$(cat "$PID_FILE")
		if kill -0 "$pid" 2>/dev/null; then
			log "stopping QEMU (pid $pid)"
			kill "$pid" 2>/dev/null || true
			sleep 1
		fi
	fi
	rm -f "$PID_FILE" "$SOCK" "$BOOT_LOG"
}

qemu_running() {
	[ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

start_qemu() {
	log "starting QEMU with kernel $LX/arch/riscv/boot/Image"
	rm -f "$SOCK" "$BOOT_LOG"

	"$QEMU" \
		-M virt,pflash0=pflash0,pflash1=pflash1 \
		-display none \
		-daemonize \
		-pidfile "$PID_FILE" \
		-m 1G \
		-smp cpus=8,sockets=1,clusters=2,cores=4,threads=1 \
		-chardev socket,id=ser0,path=$SOCK,server=on,wait=off \
		-serial chardev:ser0 \
		-kernel "$LX/arch/riscv/boot/Image" \
		-append "root=/dev/vda ro loglevel=8 ro console=ttyS0 rootwait earlycon=uart8250,mmio,0x10000000" \
		-blockdev node-name=pflash0,driver=file,read-only=on,filename="$EDK/RISCV_VIRT_CODE.fd" \
		-blockdev node-name=pflash1,driver=file,filename="$EDK/RISCV_VIRT_VARS.fd" \
		-drive if=none,file="$BR/rootfs.ext2",format=raw,id=hd0 \
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

	log "QEMU pid $(cat "$PID_FILE")"
}

wait_for_boot() {
	log "capturing serial to $BOOT_LOG and waiting for login prompt"
	socat -u UNIX-CONNECT:"$SOCK" - > "$BOOT_LOG" 2>&1 &
	local capture_pid=$!

	local t=0
	while [ $t -lt $BOOT_TIMEOUT ]; do
		if grep -q "buildroot login:" "$BOOT_LOG" 2>/dev/null; then
			kill $capture_pid 2>/dev/null || true
			wait $capture_pid 2>/dev/null || true
			log "guest reached login prompt"
			return 0
		fi
		sleep 2
		t=$((t + 2))
	done

	kill $capture_pid 2>/dev/null || true
	log "ERROR: guest did not boot within ${BOOT_TIMEOUT}s — see $BOOT_LOG"
	return 1
}

login_and_net() {
	log "logging in and bringing up network"
	send 15 <<-'EOF'
		root
		ip link set eth0 up && udhcpc -i eth0 -q >/dev/null 2>&1 || true
		ip addr show eth0 | grep -q "inet " && echo NET_UP
	EOF
}

start_http_server() {
	log "starting HTTP server on port $HTTP_PORT serving $SELFTEST_DIR"
	( cd "$SELFTEST_DIR" && python3 -m http.server "$HTTP_PORT" --bind 0.0.0.0 ) \
		> /tmp/qemu-selftest-http.log 2>&1 &
	HTTP_PID=$!
	# Give the server a moment to bind.
	sleep 1
}

stop_http_server() {
	if [ -n "${HTTP_PID:-}" ]; then
		kill "$HTTP_PID" 2>/dev/null || true
		wait "$HTTP_PID" 2>/dev/null || true
		HTTP_PID=
	fi
}

transfer_binary() {
	log "transferring resctrl_tests into guest via http://10.0.2.2:$HTTP_PORT/"
	send 20 <<EOF
wget -q http://10.0.2.2:$HTTP_PORT/resctrl_tests -O /usr/bin/resctrl_tests && chmod +x /usr/bin/resctrl_tests && echo GUEST_DL_OK
EOF
}

run_tests() {
	local args="$*"
	log "running: resctrl_tests $args"
	# Unmount in case a previous run (or init script) left it mounted.
	send "$TEST_TIMEOUT" <<EOF
umount /sys/fs/resctrl 2>/dev/null
resctrl_tests $args
echo GUEST_TEST_DONE
EOF
}

cross_build() {
	log "building resctrl selftests for RISC-V"
	make -C "$SELFTEST_DIR" \
		ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- \
		> /tmp/qemu-selftest-build.log 2>&1
	file "$SELFTEST_BIN" | grep -q RISC-V || {
		log "ERROR: built binary is not RISC-V — see /tmp/qemu-selftest-build.log"
		file "$SELFTEST_BIN"
		return 1
	}
}

cleanup() {
	stop_http_server
}
trap cleanup EXIT

# ------------------------- main ------------------------------

if [ "${1:-}" = "--shutdown" ]; then
	shutdown_qemu
	exit 0
fi

# Default test selection; any argv passes through to resctrl_tests.
TEST_ARGS=${*:--t RBWB,MWEIGHT}

cross_build

if qemu_running; then
	log "reusing running QEMU (pid $(cat "$PID_FILE"))"
else
	start_qemu
	wait_for_boot
	login_and_net
fi

start_http_server
transfer_binary
run_tests "$TEST_ARGS"

log "done. To stop QEMU: $0 --shutdown"
