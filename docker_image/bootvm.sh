#!/bin/sh

emulator=qemu-system-arm
machine=raspi0
memory=512m
dtb="/fat/bcm2708-rpi-zero-w.dtb"
kernel="/fat/kernel.img"
image_path="/filesystem.img"
network="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
root=/dev/mmcblk0p2

qemu-img info $image_path
exec ${emulator} \
  --machine "${machine}" \
  --m "${memory}" \
  --dtb "${dtb}" \
  --kernel "${kernel}" \
  --sd "${image_path}" \
  ${network} \
  --append "rw earlyprintk initcall_blacklist=bcm2835_pm_driver_init console=ttyAMA0,115200 root=${root} rootwait dwc_otg.lpm_enable=0 dwc_otg.fiq_fsm_enable=0 panic=1" \
  --serial mon:stdio \
  --display none
