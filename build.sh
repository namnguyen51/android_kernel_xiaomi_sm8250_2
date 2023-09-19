#!/bin/bash
#
# Compile script for Skyline kernel
# Copyright (C) 2020-2021 Adithya R.[B

SECONDS=0 # builtin bash timer
ZIPNAME="IMMENSITY-X-ALIOTH-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/clang-r450784e"
AK3_DIR="$(pwd)/android/AnyKernel3"
KSU_DIR="$(pwd)/KernelSU"
DEFCONFIG="alioth_defconfig"

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
	echo "AOSP clang not found! Cloning to $TC_DIR..."
	if ! git clone --depth=1 -b 17 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

if ! [ -d "$KSU_DIR" ]; then
        echo "KernelSU not found! Cloning to $KSU_DIR..."
        if ! curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash - ; then
                echo "Cloning failed! Aborting..."
                exit 1
        fi
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 Image dtbo.img

dts="out/arch/arm64/boot/dts/vendor/qcom"
build="out/arch/arm64/boot"

find $dts -name '*.dtb' -exec cat {} + >$build/dtb

kernel="out/arch/arm64/boot/Image"
dtb="out/arch/arm64/boot/dtb"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -f "$kernel" ] && [ -f "$dtb" ] && [ -f "$dtbo" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	elif ! git clone -q https://github.com/UtsavBalar1231/AnyKernel3 -b kona; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
        mkdir -p AnyKernel3/kernels/aospa
	cp $kernel $dtb $dtbo AnyKernel3/kernels/aospa
	rm -rf out/arch/arm64/boot
	cd AnyKernel3
	git checkout kona &> /dev/null
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi
