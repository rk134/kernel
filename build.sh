#!/bin/bash
#
# Compile script for QuicksilveR kernel
# Copyright (C) 2020-2021 Adithya R.

SECONDS=0 # builtin bash timer
TC_DIR="/home/rk/aospa/work/tc/linux-x86/clang-r450784d"
GCC_64_DIR="/home/rk/aospa/work/tc/aarch64-linux-android-4.9"
GCC_32_DIR="/home/rk/aospa/work/tc/arm-linux-androideabi-4.9"
AK3_DIR="$HOME/AnyKernel3"
DEFCONFIG="vendor/lahaina-qgki_defconfig"

ZIPNAME="rahul-gay-$(date '+%Y%m%d-%H%M').zip"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

MAKE_PARAMS="O=out ARCH=arm64 CC=clang \
	CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=$GCC_64_DIR/bin/aarch64-linux-android- \
        CROSS_COMPILE_COMPAT=$GCC_32_DIR/bin/arm-linux-androideabi-"

export PATH="$TC_DIR/bin:$PATH"

if [[ $1 = "-r" || $1 = "--save-regen" ]]; then
	make $MAKE_PARAMS $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make $MAKE_PARAMS $DEFCONFIG
	cp out/.config arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
	echo "Cleaned output folder"
fi

mkdir -p out
make $MAKE_PARAMS $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) $MAKE_PARAMS || exit $?
make -j$(nproc --all) $MAKE_PARAMS INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install

kernel="out/arch/arm64/boot/Image"

if [ -f "$kernel" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
		git -C AnyKernel3 checkout lisa &> /dev/null
	elif ! git clone -q https://github.com/bheatleyyy/AnyKernel3; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
        COMPILED_IMAGE=out/arch/arm64/boot/Image
        COMPILED_DTBO=out/arch/arm64/boot/dtbo.img
	mv -f ${COMPILED_IMAGE} ${COMPILED_DTBO} AnyKernel3
        find out/arch/arm64/boot/dts/vendor -name '*.dtb' -exec cat {} + > AnyKernel3/dtb
	cp $(find out/modules/lib/modules/5.4* -name '*.ko') AnyKernel3/modules/vendor/lib/modules/
	cp out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} AnyKernel3/modules/vendor/lib/modules
	cp out/modules/lib/modules/5.4*/modules.order AnyKernel3/modules/vendor/lib/modules/modules.load
	sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' AnyKernel3/modules/vendor/lib/modules/modules.dep
	sed -i 's/.*\///g' AnyKernel3/modules/vendor/lib/modules/modules.load
	rm -rf out/arch/arm64/boot out/modules
	cd AnyKernel3
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi
