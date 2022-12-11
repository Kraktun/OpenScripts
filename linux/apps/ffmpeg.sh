#!/bin/bash
set -eu

# needs the following variables set up

# FFMPEG_TARGET= # target device. Currently accepts: raspi, x64

# Note that logs to stdout are currently not shown

echo
echo_yellow "#################################################"
echo_yellow "\t FFMPEG with additional libs INSTALLATION"
echo_yellow "#################################################"
echo
echo "Press ENTER to continue"
read -p "" VAR

# check target value

case $FFMPEG_TARGET in
  raspi|x64) 
	echo "Target is $FFMPEG_TARGET" | tee -a $FFMPEG_LOG_FILE ;;
  *) 
	echo "Invalid target device specified"
	return 1 ;;
esac


local TEMP_FFMPEG_DIR=/tmp/ffmpeg_tmp

local FFMPEG_CURRENT_DIR=`pwd`
local FFMPEG_CURRENT_DATE=`date +"%Y-%m-%d_%H%M"`

local FFMPEG_LOG_FILE=$TEMP_FFMPEG_DIR/ffmpeg_log_$FFMPEG_CURRENT_DATE.log

# install required dependencies
sudo apt-get update >> /dev/null
if [ "$FFMPEG_TARGET" = "raspi" ]; then
	sudo apt-get install -y -q build-essential git autoconf automake cmake libtool >> /dev/null
elif [ "$FFMPEG_TARGET" = "x64" ]; then
	sudo apt-get install -y -q build-essential git autoconf automake cmake libtool libass-dev libfreetype6-dev libgnutls28-dev libmp3lame-dev libsdl2-dev \
		libva-dev libvdpau-dev  libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev meson ninja-build pkg-config texinfo wget yasm zlib1g-dev libunistring-dev >> /dev/null
fi

# set temporary dir
mkdir -p $TEMP_FFMPEG_DIR

# dav1d requires nasm, so start with that
# TODO: skip if already installed
if [ "$FFMPEG_TARGET" = "x64" ]; then
	cd $TEMP_FFMPEG_DIR
	echo "-----------------------------------------------------" | tee -a $FFMPEG_LOG_FILE
	echo "Installing nasm" | tee -a $FFMPEG_LOG_FILE
	wget -q https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.bz2
	tar xjf nasm-2.15.05.tar.bz2
	cd nasm-2.15.05
	echo 
	./autogen.sh  >> $FFMPEG_LOG_FILE 2>&1
	echo "Configuring..." | tee -a $FFMPEG_LOG_FILE
	./configure >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	echo "Building..." | tee -a $FFMPEG_LOG_FILE
	make -j$(nproc) >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	echo "Installing..." | tee -a $FFMPEG_LOG_FILE
	sudo make install >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	rm -rf $TEMP_FFMPEG_DIR/nasm-2.15.05
	rm $TEMP_FFMPEG_DIR/nasm-2.15.05.tar.bz2
fi

# install aac
cd $TEMP_FFMPEG_DIR
echo "-----------------------------------------------------" | tee -a $FFMPEG_LOG_FILE
echo "Installing aac" | tee -a $FFMPEG_LOG_FILE
git clone --depth 1 https://github.com/mstorsjo/fdk-aac >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
cd fdk-aac
echo "Configuring..." | tee -a $FFMPEG_LOG_FILE
autoreconf -fiv >> $FFMPEG_LOG_FILE   2>&1
./configure --disable-shared >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
echo "Building..." | tee -a $FFMPEG_LOG_FILE
make -j$(nproc) >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
echo "Installing..." | tee -a $FFMPEG_LOG_FILE
sudo make install >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
rm -rf $TEMP_FFMPEG_DIR/fdk-aac

# install x264
cd $TEMP_FFMPEG_DIR
echo "-----------------------------------------------------" | tee -a $FFMPEG_LOG_FILE
echo "Installing x264" | tee -a $FFMPEG_LOG_FILE
git clone --depth 1 https://code.videolan.org/videolan/x264 >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
cd x264
echo "Configuring..." | tee -a $FFMPEG_LOG_FILE
if [ "$FFMPEG_TARGET" = "raspi" ]; then
	./configure --host=arm-unknown-linux-gnueabi --enable-static --disable-opencl >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
elif [ "$FFMPEG_TARGET" = "x64" ]; then
	./configure --enable-static >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
fi
echo "Building..." | tee -a $FFMPEG_LOG_FILE
make -j$(nproc) >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
echo "Installing..." | tee -a $FFMPEG_LOG_FILE
sudo make install >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
rm -rf $TEMP_FFMPEG_DIR/x264

# install x265 only for x64
if [ "$FFMPEG_TARGET" = "x64" ]; then
	cd $TEMP_FFMPEG_DIR
	echo "-----------------------------------------------------" | tee -a $FFMPEG_LOG_FILE
	echo "Installing x265" | tee -a $FFMPEG_LOG_FILE
	sudo apt-get install -y -q libnuma-dev >> /dev/null
	wget -q -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/master.tar.bz2
	tar xjf x265.tar.bz2
	cd multicoreware*/build/linux
	echo "Configuring..." | tee -a $FFMPEG_LOG_FILE
	cmake -G "Unix Makefiles"  -Wno-dev -DENABLE_SHARED=off ../../source >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	echo "Building..." | tee -a $FFMPEG_LOG_FILE
	make -j$(nproc) >> $FFMPEG_LOG_FILE   2>&1
	echo "Installing..." | tee -a $FFMPEG_LOG_FILE
	sudo make install >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	rm -rf $TEMP_FFMPEG_DIR/multicoreware*
	rm $TEMP_FFMPEG_DIR/x265.tar.bz2
fi

# install vp8/vp9
if [ "$FFMPEG_TARGET" = "x64" ]; then
	cd $TEMP_FFMPEG_DIR
	echo "-----------------------------------------------------" | tee -a $FFMPEG_LOG_FILE
	echo "Installing vp8/vp9" | tee -a $FFMPEG_LOG_FILE
	git -C libvpx pull 2> /dev/null || git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	cd libvpx
	echo "Configuring..." | tee -a $FFMPEG_LOG_FILE
	./configure --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm  >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	echo "Building..." | tee -a $FFMPEG_LOG_FILE
	make  -j$(nproc)  >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	echo "Installing..." | tee -a $FFMPEG_LOG_FILE
	sudo make install >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	rm -rf $TEMP_FFMPEG_DIR/libvpx
fi

# install libopus
if [ "$FFMPEG_TARGET" = "x64" ]; then
	cd $TEMP_FFMPEG_DIR
	echo "-----------------------------------------------------" | tee -a $FFMPEG_LOG_FILE
	echo "Installing opus" | tee -a $FFMPEG_LOG_FILE
	git -C opus pull 2> /dev/null || git clone --depth 1 https://github.com/xiph/opus.git >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	cd opus
	echo "Configuring..." | tee -a $FFMPEG_LOG_FILE
	./autogen.sh >> $FFMPEG_LOG_FILE  2>&1
	./configure --disable-shared >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	echo "Building..." | tee -a $FFMPEG_LOG_FILE
	make -j$(nproc) >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	echo "Installing..." | tee -a $FFMPEG_LOG_FILE
	sudo make install >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	rm -rf $TEMP_FFMPEG_DIR/opus
fi

# install dav1d
if [ "$FFMPEG_TARGET" = "x64" ]; then
	cd $TEMP_FFMPEG_DIR
	echo "-----------------------------------------------------" | tee -a $FFMPEG_LOG_FILE
	echo "Installing dav1d" | tee -a $FFMPEG_LOG_FILE
	git -C dav1d pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/dav1d.git >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	mkdir -p dav1d/build 
	cd dav1d/build
	echo "Configuring..." | tee -a $FFMPEG_LOG_FILE
	meson setup -Denable_tools=false -Denable_tests=false --default-library=static ..  >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	echo "Building..." | tee -a $FFMPEG_LOG_FILE
	ninja >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	echo "Installing..." | tee -a $FFMPEG_LOG_FILE
	sudo ninja install >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
	rm -rf $TEMP_FFMPEG_DIR/dav1d
fi

# update library cache to avoid linking problems
echo "Updating library cache" | tee -a $FFMPEG_LOG_FILE
sudo ldconfig

# install ffmpeg
cd $TEMP_FFMPEG_DIR
echo "-----------------------------------------------------" | tee -a $FFMPEG_LOG_FILE
echo "Installing ffmpeg" | tee -a $FFMPEG_LOG_FILE
git clone git://source.ffmpeg.org/ffmpeg --depth=1 >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
cd ffmpeg
echo "Configuring..." | tee -a $FFMPEG_LOG_FILE
if [ "$FFMPEG_TARGET" = "raspi" ]; then
	./configure \
		--extra-cflags="-I/usr/local/include" \
		--extra-ldflags="-latomic" \
		--arch=armel \
		--target-os=linux \
		--enable-gpl \
		--enable-libx264 \
		--enable-nonfree \
		--enable-libfdk-aac \
		 >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
elif [ "$FFMPEG_TARGET" = "x64" ]; then
	./configure \
		--pkg-config-flags="--static" \
		--extra-cflags="-I/usr/local/include" \
		--extra-libs="-lpthread -lm" \
		--ld="g++" \
		--enable-gpl \
		--enable-gnutls \
		--enable-libass \
		--enable-libfdk-aac \
		--enable-libfreetype \
		--enable-libmp3lame \
		--enable-libopus \
		--enable-libdav1d \
		--enable-libvorbis \
		--enable-libvpx \
		--enable-libx264 \
		--enable-libx265 \
		--enable-nonfree \
		 >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
fi
echo "Building..." | tee -a $FFMPEG_LOG_FILE
make -j$(nproc)  >> $FFMPEG_LOG_FILE  2>&1
echo "Installing..." | tee -a $FFMPEG_LOG_FILE
sudo make install >> $FFMPEG_LOG_FILE  2> >(tee -a $FFMPEG_LOG_FILE >&2)
rm -rf $TEMP_FFMPEG_DIR/ffmpeg

echo
echo_green "-------------------------------------------------"
echo_green "\tInstallation complete"
echo_green "-------------------------------------------------"
echo
