#!/bin/bash
set -eE

function usage () {
  printf "%s: build Textadept and some modules\nUsage:\n" $(basename $0)
  printf " %s [-v TAVERSION] [-r RELEASE] [-2] [distro]\n\n" $(basename $0)
  printf "   -v TAVERSION: TextAdept version\n"
  printf "   -r RELEASE: distro release\n"
  printf "   -2: build TA for GTK2 (default is GTK3)\n\n"

  printf " default distro: $1\n"
  printf " default release: $2\n"
  printf " default version: %s\n" "$3"
}

function edit_sed() {
	#
	# get the latest changeset from the log
	#
	CHGSET=`hg log -l 1 | awk -F: '/changeset/{print $2}' | awk '{$1=$1}1'`
	#
	# Edit the changelog
	#
	sed -i -E "/^textadept/s/[0-9]+\.[0-9a-z.-]+/$2/
/Update /s/[0-9]+$/$CHGSET/
/^ --/s/>  [A-Z].*$/>  $(LC_ALL=C date '+%a, %d %b %Y %H:%m:%S %z')/" $1
}

DISTRO=ubuntu
TAVERSION=11.0alpha3-1
RELEASE=20.04
GTKVERSION="3.0"
GTK3="GTK3=1"

while getopts ":hv:r:2" opt; do
  case $opt in
    r)
      RELEASE=${OPTARG}
      ;;
    v)
      TAVERSION=${OPTARG}
      ;;
    2)
      unset GTK3
      GTKVERSION="2.4"
      ;;
    h|\?)
      usage ubuntu ${RELEASE} ${TAVERSION}
      exit
    ;;
  esac
done
shift $((OPTIND-1))

DISTRO=${1:-ubuntu}
IMAGE=${DISTRO}:${RELEASE}

#
# Debian docker images with -slim avoid many unnecesary dependencies and files
#
#IMAGE=$(echo ${DISTRO}${RELEASE} | sed 's/-slim//g')/libgtkmm-${GTKVERSION}:latest
DEBDIR=$(echo ${DISTRO}-${RELEASE} | sed 's/-slim//g')

[ -d  ${DEBDIR} ] && rm -vf ${DEBDIR}/textadept*${TAVERSION}*.deb
[ -d  ${DEBDIR} ] || mkdir -v ${DEBDIR}

function cleanup () {
	if [ "$?" == "0" ]; then
		echo "Built successfully ($?): removing container"
		docker container rm --force build-z
	fi
	# [ $? -gt 0 ] && rm -rf ${DEBDIR}
	chown ${SUDO_USER}:${SUDO_USER} ${DEBDIR}
	chmod 0755 ${DEBDIR}
	chmod 0644 ${DEBDIR}/*
}

trap cleanup EXIT

function apt_install () {
  echo "DEBIAN_FRONTEND=noninteractive TZ=Europe/Madrid apt-get install -y $@"
}

function get_debs() {
	#
	# Copy the executables and modules
	#
	for f in $(docker exec build-z bash -c "cd /root; ls *.deb")
	do
		echo "build-z:/root/$f --> ${DEBDIR}"
		docker cp build-z:/root/$f ${DEBDIR}
	done
}
# TODO: build the docker image if doesn't exist à la:
# docker build -t myimage:latest -f- . <<EOF
# FROM busybox
# COPY somefile.txt .
# RUN cat /somefile.txt
# EOF

#docker pull ${IMAGE}
docker container rm --force build-z || true

docker run -it -d --name build-z ${IMAGE} bash
#
# get the development libraries
#
docker exec build-z bash -c "DEBIAN_FRONTEND=noninteractive apt-get update"
docker exec build-z bash -c "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
docker exec build-z bash -c "$(apt_install git wget)"
#
# TODO: clone by TextAdept release
#
docker exec build-z bash -c "cd /root; git clone https://github.com/orbitalquark/textadept"
docker exec build-z bash -c "cd /root; mkdir textadept_modules"
for mod in css file-diff html python rest ruby yaml # markdown yang
do
	docker exec build-z bash -c "cd /root/textadept_modules; git clone https://github.com/orbitalquark/textadept-$mod $mod"
done
docker exec build-z bash -c "$(apt_install debhelper debmake autotools-dev fakeroot)"
docker exec build-z bash -c "$(apt_install libgtkmm-${GTKVERSION}-dev libncurses-dev)"

cd ta
sed -iE "s/libgtkmm-.../libtgkmm-${GTKVERSION}/g" debian/control
edit_sed debian/changelog "$TAVERSION"
cat debian/control
tar -cvf /tmp/ta-debian.tar debian
echo "Copying the debian infrastructure to the container..."
docker cp /tmp/ta-debian.tar build-z:/root/textadept
cd ../ta-modules
edit_sed debian/changelog "$TAVERSION"
tar -cvf /tmp/tam-debian.tar debian
echo "Copying the debian infrastructure to the container..."
docker cp /tmp/tam-debian.tar build-z:/root/textadept_modules
cd ..

docker exec build-z bash -c "cd /root/textadept; tar -xvf ta-debian.tar"
docker exec build-z bash -c "cd /root/textadept; fakeroot debian/rules ${GTK3} clean binary"
get_debs
#
# Get the Debian infrastructure for the modules and
# create the module packages
#
docker exec build-z bash -c "cd /root/textadept_modules; tar -xvf tam-debian.tar"
docker exec build-z bash -c "cd /root/textadept_modules; fakeroot debian/rules clean binary"
get_debs
