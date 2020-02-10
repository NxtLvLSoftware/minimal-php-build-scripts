#!/bin/bash
[ -z "$PHP_VERSION" ] && PHP_VERSION="7.3.12"

PHP_IS_BETA="no"

function write {
  echo "$1"
}

function write_out {
	write "[$1] $2"
}

function write_info {
	write_out INFO "$1" >&2
}

function write_error {
	write_out ERROR "$1" >&2
}

write "Minimal CI PHP compile script for Linux & MacOS"
DIR="$(pwd)"
[ -z "$PHP_INSTALL_DIR" ] && PHP_INSTALL_DIR="$DIR/php"

date > "$DIR/install.log" 2>&1
uname -a >> "$DIR/install.log" 2>&1

write_info "Checking dependencies"

COMPILE_SH_DEPENDENCIES=( make autoconf automake m4 bison g++ )
ERRORS=0
for(( i=0; i<${#COMPILE_SH_DEPENDENCIES[@]}; i++ ))
do
	type "${COMPILE_SH_DEPENDENCIES[$i]}" >> "$DIR/install.log" 2>&1 || { write_error "Please install \"${COMPILE_SH_DEPENDENCIES[$i]}\""; ((ERRORS++)); }
done

type wget >> "$DIR/install.log" 2>&1 || type curl >> "$DIR/install.log" || { write_error "Please install \"wget\" or \"curl\""; ((ERRORS++)); }

if [ $ERRORS -ne 0 ]; then
	exit 1
fi

#Needed to use aliases
shopt -s expand_aliases
type wget >> "$DIR/install.log" 2>&1
if [ $? -eq 0 ]; then
	alias download_file="wget --no-check-certificate -q -O -"
else
	type curl >> "$DIR/install.log" 2>&1
	if [ $? -eq 0 ]; then
		alias download_file="curl --insecure --silent --show-error --location --globoff"
	else
		echo "error, curl or wget not found"
		exit 1
	fi
fi

[ -z "$CC" ] && export CC="gcc"
[ -z "$CXX" ] && export CXX="g++"
#[ -z "$AR" ] && export AR="gcc-ar"
[ -z "$RANLIB" ] && export RANLIB=ranlib

COMPILE_TARGET=""
COMPILE_FANCY="no"
DO_STATIC="no"
DO_CLEANUP="no"
HAS_ZTS=""

while getopts "::t:j:snz" OPTION; do
	case $OPTION in
		t)
			echo "[opt] Set target to $OPTARG"
			COMPILE_TARGET="$OPTARG"
			;;
		j)
			echo "[opt] Set make threads to $OPTARG"
			THREADS="$OPTARG"
			;;
		s)
			echo "[opt] Will compile everything statically"
			DO_STATIC="yes"
			CFLAGS="$CFLAGS -static"
			;;
		n)
			echo "[opt] Will remove sources after completing compilation"
			DO_CLEANUP="yes"
			;;
		z)
			echo "[opt] Will compile with zend thread safety"
			HAS_ZTS="--enable-maintainer-zts"
			;;
		\?)
			echo "Invalid option: -$OPTION$OPTARG" >&2
			exit 1
			;;
	esac
done

if [[ "$COMPILE_TARGET" == "" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
	COMPILE_TARGET="mac"
fi

if [[ "$COMPILE_TARGET" == "linux" ]] || [[ "$COMPILE_TARGET" == "linux64" ]]; then
	[ -z "$march" ] && march=x86-64;
	[ -z "$mtune" ] && mtune=nocona;
	CFLAGS="$CFLAGS -m64"
	echo "[INFO] Compiling for Linux x86_64"
elif [[ "$COMPILE_TARGET" == "mac" ]] || [[ "$COMPILE_TARGET" == "mac64" ]]; then
	[ -z "$march" ] && march=core2;
	[ -z "$mtune" ] && mtune=generic;
	[ -z "$MACOSX_DEPLOYMENT_TARGET" ] && export MACOSX_DEPLOYMENT_TARGET=10.9;
	CFLAGS="$CFLAGS -m64 -arch x86_64 -fomit-frame-pointer -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
	LDFLAGS="$LDFLAGS -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
	if [ "$DO_STATIC" == "no" ]; then
		LDFLAGS="$LDFLAGS -Wl,-rpath,@loader_path/../lib";
		export DYLD_LIBRARY_PATH="@loader_path/../lib"
	fi
	CFLAGS="$CFLAGS -Qunused-arguments -Wno-error=unused-command-line-argument"
	echo "[INFO] Compiling for Intel MacOS x86_64"
#TODO: add aarch64 platforms (ios, android, rpi)
elif [[ -z "$CFLAGS" ]]; then
	if [[ `getconf LONG_BIT` == "64" ]]; then
		echo "[INFO] Compiling for current machine using 64-bit"
		if [[ "$(uname -m)" != "aarch64" ]]; then
			CFLAGS="-m64 $CFLAGS"
		fi
	else
		echo "[INFO] Compiling for current machine using 32-bit"
		if [[ "$(uname -m)" != "aarch32" ]]; then
			CFLAGS="-m32 $CFLAGS"
		fi
	fi
fi

echo "#include <stdio.h>" > test.c
echo "int main(void){" >> test.c
echo "printf(\"Hello world\n\");" >> test.c
echo "return 0;" >> test.c
echo "}" >> test.c

type ${CC} >> "$DIR/install.log" 2>&1 || { write_error "Please install \"$CC\""; exit 1; }

[[ -z "$THREADS" ]] && THREADS=1;
[[ -z "$march" ]] && march=native;
[[ -z "$mtune" ]] && mtune=native;
[[ -z "$CFLAGS" ]] && CFLAGS="";

if [[ "$DO_STATIC" == "no" ]]; then
	[[ -z "$LDFLAGS" ]] && LDFLAGS="-Wl,-rpath='\$\$ORIGIN/../lib' -Wl,-rpath-link='\$\$ORIGIN/../lib'";
fi

[[ -z "$CONFIGURE_FLAGS" ]] && CONFIGURE_FLAGS="";

if [[ "$mtune" != "none" ]]; then
	echo "$CC -march=$march -mtune=$mtune $CFLAGS -o test test.c" >>"$DIR/install.log"
	$CC -march=$march -mtune=$mtune $CFLAGS -o test test.c >> "$DIR/install.log" 2>&1
	if [ $? -eq 0 ]; then
		CFLAGS="-march=$march -mtune=$mtune -fno-gcse $CFLAGS"
	fi
else
	echo "$CC -march=$march $CFLAGS -o test test.c" >> "$DIR/install.log"
	$CC -march=$march $CFLAGS -o test test.c >> "$DIR/install.log" 2>&1
	if [[ $? -eq 0 ]]; then
		CFLAGS="-march=$march -fno-gcse $CFLAGS"
	fi
fi

rm test.* >> "$DIR/install.log" 2>&1
rm test >> "$DIR/install.log" 2>&1

export CC="$CC"
export CXX="$CXX"
export CFLAGS="-O0 -fPIC $CFLAGS"
export CXXFLAGS="$CFLAGS $CXXFLAGS"
export LDFLAGS="$LDFLAGS"
export CPPFLAGS="$CPPFLAGS"
export LIBRARY_PATH="$PHP_INSTALL_DIR/lib:$LIBRARY_PATH"

rm -r -f install_data/ >> "$DIR/install.log" 2>&1
rm -r -f bin/ >> "$DIR/install.log" 2>&1
mkdir -m 0755 install_data >> "$DIR/install.log" 2>&1
mkdir -m 0755 bin >> "$DIR/install.log" 2>&1
mkdir -m 0755 php >> "$DIR/install.log" 2>&1
cd install_data
set -e

#PHP 7
echo -n "[PHP] downloading $PHP_VERSION..."

if [[ "$PHP_IS_BETA" == "yes" ]]; then
	download_file "https://github.com/php/php-src/archive/php-$PHP_VERSION.tar.gz" | tar -zx >> "$DIR/install.log" 2>&1
	mv php-src-php-${PHP_VERSION} php
else
	download_file "http://php.net/get/php-$PHP_VERSION.tar.gz/from/this/mirror" | tar -zx >> "$DIR/install.log" 2>&1
	mv php-${PHP_VERSION} php
fi

echo " done!"
PHP_OPTIMIZATION="--disable-inline-optimization "

echo "[PHP] checking..."
cd php
rm -f ./aclocal.m4 >> "$DIR/install.log" 2>&1
rm -rf ./autom4te.cache/ >> "$DIR/install.log" 2>&1
rm -f ./configure >> "$DIR/install.log" 2>&1

./buildconf --force >> "$DIR/install.log" 2>&1

if [[ "$DO_STATIC" == "yes" ]]; then
	export LIBS="$LIBS -ldl"
fi

RANLIB=${RANLIB} CFLAGS=${CFLAGS} CXXFLAGS=${CXXFLAGS} LDFLAGS=${LDFLAGS} ./configure ${PHP_OPTIMIZATION} --prefix="$PHP_INSTALL_DIR" \
--disable-all \
--disable-cgi \
--enable-debug \
${HAS_ZTS} \
${CONFIGURE_FLAGS} >> "$DIR/install.log" 2>&1

sed -i=".backup" 's/PHP_BINARIES. pharcmd$/PHP_BINARIES)/g' Makefile
sed -i=".backup" 's/install-programs install-pharcmd$/install-programs/g' Makefile

echo -n " compiling..."
make -j ${THREADS} >> "$DIR/install.log" 2>&1
echo -n " installing..."
make install >> "$DIR/install.log" 2>&1

if [[ "$(uname -s)" == "Darwin" ]]; then
	set +e
	install_name_tool -delete_rpath "$PHP_INSTALL_DIR/lib" "$PHP_INSTALL_DIR/bin/php" >> "$DIR/install.log" 2>&1

	IFS=$'\n' OTOOL_OUTPUT=($(otool -L "$PHP_INSTALL_DIR/bin/php"))

	for (( i=0; i<${#OTOOL_OUTPUT[@]}; i++ ))
		do
		CURRENT_DYLIB_NAME=$(echo ${OTOOL_OUTPUT[$i]} | sed 's# (compatibility version .*##' | xargs)
		if [[ $CURRENT_DYLIB_NAME == "$PHP_INSTALL_DIR/lib/"*".dylib"* ]]; then
			NEW_DYLIB_NAME=$(echo "$CURRENT_DYLIB_NAME" | sed "s{$PHP_INSTALL_DIR/lib{@loader_path/../lib{" | xargs)
			install_name_tool -change "$CURRENT_DYLIB_NAME" "$NEW_DYLIB_NAME" "$PHP_INSTALL_DIR/bin/php" >> "$DIR/install.log" 2>&1
		fi
	done

	install_name_tool -change "$PHP_INSTALL_DIR/lib/libssl.1.0.0.dylib" "@loader_path/../lib/libssl.1.0.0.dylib" "$PHP_INSTALL_DIR/lib/libcurl.4.dylib" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$PHP_INSTALL_DIR/lib/libcrypto.1.0.0.dylib" "@loader_path/../lib/libcrypto.1.0.0.dylib" "$PHP_INSTALL_DIR/lib/libcurl.4.dylib" >> "$DIR/install.log" 2>&1
	chmod 0777 "$PHP_INSTALL_DIR/lib/libssl.1.0.0.dylib" >> "$DIR/install.log" 2>&1
	install_name_tool -change "$PHP_INSTALL_DIR/lib/libcrypto.1.0.0.dylib" "@loader_path/libcrypto.1.0.0.dylib" "$PHP_INSTALL_DIR/lib/libssl.1.0.0.dylib" >> "$DIR/install.log" 2>&1
	chmod 0755 "$PHP_INSTALL_DIR/lib/libssl.1.0.0.dylib" >> "$DIR/install.log" 2>&1
	set -e
fi

echo -n " generating php.ini..."
trap - DEBUG
TIMEZONE=$(date +%Z)
echo "memory_limit=1024M" >> "$PHP_INSTALL_DIR/bin/php.ini"
echo "date.timezone=$TIMEZONE" >> "$PHP_INSTALL_DIR/bin/php.ini"
echo "short_open_tag=0" >> "$PHP_INSTALL_DIR/bin/php.ini"
echo "asp_tags=0" >> "$PHP_INSTALL_DIR/bin/php.ini"
echo "phar.readonly=0" >> "$PHP_INSTALL_DIR/bin/php.ini"
echo "phar.require_hash=1" >> "$PHP_INSTALL_DIR/bin/php.ini"
echo "zend.assertions=1" >> "$PHP_INSTALL_DIR/bin/php.ini"
echo "error_reporting=-1" >> "$PHP_INSTALL_DIR/bin/php.ini"
echo "display_errors=1" >> "$PHP_INSTALL_DIR/bin/php.ini"
echo "display_startup_errors=1" >> "$PHP_INSTALL_DIR/bin/php.ini"

echo " done!"

cd "$DIR"
if [ "$DO_CLEANUP" == "yes" ]; then
	wite_info "Cleaning up..."
	rm -r -f install_data/ >> "$DIR/install.log" 2>&1
	rm -f php/bin/curl* >> "$DIR/install.log" 2>&1
	rm -f php/bin/curl-config* >> "$DIR/install.log" 2>&1
	rm -f php/bin/c_rehash* >> "$DIR/install.log" 2>&1
	rm -f php/bin/openssl* >> "$DIR/install.log" 2>&1
	rm -r -f php/man >> "$DIR/install.log" 2>&1
	rm -r -f php/share/man >> "$DIR/install.log" 2>&1
	rm -r -f php/php >> "$DIR/install.log" 2>&1
	rm -r -f php/misc >> "$DIR/install.log" 2>&1
	rm -r -f php/lib/*.a >> "$DIR/install.log" 2>&1
	rm -r -f php/lib/*.la >> "$DIR/install.log" 2>&1
	rm -r -f php/include >> "$DIR/install.log" 2>&1
	echo " done!"
fi