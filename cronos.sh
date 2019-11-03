#!/bin/bash
#
# Cronos Build Script V3.3
# For Exynos7420
# Coded by BlackMesa/AnanJaser1211 @2019
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software

# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Main Dir
CR_DIR=$(pwd)
# Define toolchan path
CR_TC=~/Projects/Android/Renouveau/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
# Define proper arch and dir for dts files
CR_DTS=arch/arm64/boot/dts
# Define boot.img out dir
CR_OUT=$CR_DIR/Helios/Out
# Presistant A.I.K Location
CR_AIK=$CR_DIR/Helios/A.I.K
# Main Ramdisk Location
CR_RAMDISK=$CR_DIR/Helios/Ramdisk
# Main Edify Location
CR_EDIFY=$CR_DIR/Helios/Edify
# Compiled image name and location (Image/zImage)
CR_KERNEL=$CR_DIR/arch/arm64/boot/Image
# Compiled dtb by dtbtool
CR_DTB=$CR_DIR/boot.img-dtb
# Kernel Name and Version
CR_VERSION=v3.5.2
CR_NAME=HeliosOreo_Renouveau
# Thread count
CR_JOBS=$((`nproc`-1))
# Target android version and platform (7/n/8/o/9/p)
CR_ANDROID=p
CR_PLATFORM=9.0.0
# Target ARCH
CR_ARCH=arm64
# Current Date
CR_DATE=$(date +%Y%m%d)
# Init build
export CROSS_COMPILE=$CR_TC
# General init
export ANDROID_MAJOR_VERSION=$CR_ANDROID
export PLATFORM_VERSION=$CR_PLATFORM
export $CR_ARCH
##########################################
# Device specific Variables [SM-G92X]
CR_DTSFILES_G92X="G92X_universal.dtb"
CR_CONFG_G92X=G92X_defconfig
CR_CONFG_G92XUS=G92X_us_defconfig
CR_VARIANT_G92X=G92X
CR_VARIANT_G92XUS=G92XUS
#####################################################

# Script functions

read -p "Clean source (y/n) > " yn
if [ "$yn" = "Y" -o "$yn" = "y" ]; then
     echo "Clean Build"    
     make clean && make mrproper    
     rm -r -f $CR_DTB
     rm -rf $CR_DTS/.*.tmp
     rm -rf $CR_DTS/.*.cmd
     rm -rf $CR_DTS/*.dtb      
else
     echo "Dirty Build"
     rm -r -f $CR_DTB
     rm -rf $CR_DTS/.*.tmp
     rm -rf $CR_DTS/.*.cmd
     rm -rf $CR_DTS/*.dtb          
fi

BUILD_ZIMAGE()
{
	echo "----------------------------------------------"
	echo " "
	echo "Building zImage for $CR_VARIANT"
	export LOCALVERSION=-$CR_NAME-$CR_VERSION-$CR_VARIANT-$CR_DATE
	make  $CR_CONFG
	make -j$CR_JOBS
	if [ ! -e ./arch/arm64/boot/Image ]; then
	exit 0;
	echo "Image Failed to Compile"
	echo " Abort "
	fi
	du -k "$CR_KERNEL" | cut -f1 >sizT
	sizT=$(head -n 1 sizT)
	rm -rf sizT 
	echo " "
	echo "----------------------------------------------"
}
BUILD_DTB()
{
	echo "----------------------------------------------"
	echo " "
	echo "Building DTB for $CR_VARIANT"
	# Use the DTS list provided in the build script.
	# This source does not compile dtbs while doing Image
	make $CR_DTSFILES
	./scripts/dtbTool/dtbTool -o $CR_DTB -d $CR_DTS/ -s 2048
	if [ ! -e $CR_DTB ]; then
	exit 0;
	echo "DTB Failed to Compile"
	echo " Abort "
	fi    
	rm -rf $CR_DTS/.*.tmp
	rm -rf $CR_DTS/.*.cmd
	rm -rf $CR_DTS/*.dtb
	du -k "$CR_DTB" | cut -f1 >sizdT
	sizdT=$(head -n 1 sizdT)    
	rm -rf sizdT
	echo " "
	echo "----------------------------------------------"
}
PACK_BOOT_IMG()
{
	echo "----------------------------------------------"
	echo " "
	echo "Building Boot.img for $CR_VARIANT"
	cp -rf $CR_RAMDISK/* $CR_AIK
	# Copy Ramdisk
	cp -rf $CR_RAMDISK/* $CR_AIK
	# Move Compiled kernel and dtb to A.I.K Folder
	mv $CR_KERNEL $CR_AIK/split_img/boot.img-zImage
	mv $CR_DTB $CR_AIK/split_img/boot.img-dtb
	# Create boot.img
	$CR_AIK/repackimg.sh
	# Remove red warning at boot
	echo -n "SEANDROIDENFORCE" » $CR_AIK/image-new.img
	# Remove old out dir if exists
	rm -rf $CR_OUT/$CR_VARIANT
	# Make out dir
	mkdir -p $CR_OUT/$CR_VARIANT
	# Move boot.img to out dir
	mv $CR_AIK/image-new.img $CR_OUT/$CR_VARIANT/$CR_NAME-$CR_VERSION-$CR_DATE-$CR_VARIANT.img
	du -k "$CR_OUT/$CR_VARIANT/$CR_NAME-$CR_VERSION-$CR_DATE-$CR_VARIANT.img" | cut -f1 >sizkT
	
	### EDIFY ###
	# Make edify script directory
	mkdir -p $CR_OUT/$CR_VARIANT/META-INF/com/google/android
	# Write edify script
	cat >$CR_OUT/$CR_VARIANT/META-INF/com/google/android/updater-script <<EOL
ui_print("*******************************************");
ui_print("*   Helios for AOSP 8.1 Oreo   *");
ui_print("*   Version: v3.5.2            *");
ui_print("*   Variant: ${CR_VARIANT}             *");
ui_print("*******************************************");
ui_print("*    Credits:                                     *");
ui_print("*    Noxxxious for the base for S6         *");
ui_print("*    ananjaser1211 for the rebuild for N5   *");
ui_print("*    JoshuaDoes for porting it to AOSP for N5/S6    *");

ui_print("> Flashing kernel...");
package_extract_file("${CR_NAME}-${CR_VERSION}-${CR_DATE}-${CR_VARIANT}.img", "/dev/block/platform/15570000.ufs/by-name/BOOT");

set_progress(1.000000);
ui_print("****************************************");
ui_print("*          Install Complete!           *");
ui_print("****************************************");
EOL
	# Copy update-binary
	cp -f $CR_EDIFY/update-binary $CR_OUT/$CR_VARIANT/META-INF/com/google/android/update-binary
	# Copy CERT.RSA
	cp -f $CR_EDIFY/CERT.RSA $CR_OUT/$CR_VARIANT/META-INF/CERT.RSA
	# Copy CERT.SF
	cp -f $CR_EDIFY/CERT.SF $CR_OUT/$CR_VARIANT/META-INF/CERT.SF
	# Copy MANIFEST.MF
	cp -f $CR_EDIFY/MANIFEST.MF $CR_OUT/$CR_VARIANT/META-INF/MANIFEST.MF
	# Zip up the new installer for flashing
	zip -r $CR_OUT/$CR_VARIANT/$CR_NAME-$CR_VERSION-$CR_DATE-$CR_VARIANT.zip $CR_OUT/$CR_VARIANT/*

	sizkT=$(head -n 1 sizkT)
	rm -rf sizkT
	echo " "
	$CR_AIK/cleanup.sh
}
# Main Menu
clear
echo "----------------------------------------------"
echo "$CR_NAME $CR_VERSION Build Script"
echo "----------------------------------------------"
PS3='Please select your option (1-3): '
menuvar=("SM-G92X" "SM-G92XUS" "Exit")
select menuvar in "${menuvar[@]}"
do
    case $menuvar in
        "SM-G92X")
            clear
            echo "Starting $CR_VARIANT_G92X kernel build..."
            CR_VARIANT=$CR_VARIANT_G92X
            CR_CONFG=$CR_CONFG_G92X
            CR_DTSFILES=$CR_DTSFILES_G92X
            BUILD_ZIMAGE
            BUILD_DTB
            PACK_BOOT_IMG
            echo " "
            echo "----------------------------------------------"
            echo "$CR_VARIANT kernel build finished."
            echo "Compiled DTB Size = $sizdT Kb"
            echo "Kernel Image Size = $sizT Kb"
            echo "Boot Image   Size = $sizkT Kb"
            echo "$CR_OUT/$CR_VARIANT/$CR_NAME-$CR_VERSION-$CR_DATE-$CR_VARIANT.(img/zip) Ready"
            echo "Press Any key to end the script"
            echo "----------------------------------------------"
            read -n1 -r key
            break
            ;;
         "SM-G92XUS")
            clear
            echo "Starting $CR_VARIANT_G92X kernel build..."
            CR_VARIANT=$CR_VARIANT_G92XUS
            CR_CONFG=$CR_CONFG_G92XUS
            CR_DTSFILES=$CR_DTSFILES_G92X
            BUILD_ZIMAGE
            BUILD_DTB
            PACK_BOOT_IMG
            echo " "
            echo "----------------------------------------------"
            echo "$CR_VARIANT kernel build finished."
            echo "Compiled DTB Size = $sizdT Kb"
            echo "Kernel Image Size = $sizT Kb"
            echo "Boot Image   Size = $sizkT Kb"
            echo "$CR_OUT/$CR_VARIANT/$CR_NAME-$CR_VERSION-$CR_DATE-$CR_VARIANT.(img/zip) Ready"
            echo "Press Any key to end the script"
            echo "----------------------------------------------"
            read -n1 -r key
            break
            ;;        
            "Exit")
            break
            ;;
        *) echo Invalid option.;;
    esac
done
