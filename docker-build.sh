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
	# CHGSET=`hg log -l 1 | awk -F: '/changeset/{print $2}' | awk '{$1=$1}1'`
	#
	# Edit the changelog
	#
	sed -i -E "/^textadept/s/[0-9]+\.[0-9a-z.-]+/$2/
/^ --/s/>  [A-Z].*$/>  $(LC_ALL=C date '+%a, %d %b %Y %H:%m:%S %z')/" $1
}

DISTRO=ubuntu
TAVERSION=11.0
RELEASE=20.04
GTKVERSION="3.0"
GTK3="GTK3=1"
KEEP=0

while getopts ":hv:r:2k" opt; do
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
    k)
      KEEP=1
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

if [ $KEEP -ne 1 ]; then
  [ -d  ${DEBDIR} ] && rm -vf ${DEBDIR}/textadept*${TAVERSION}*.deb
fi
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
#
# Update only what is strictly necessary
#
# docker exec build-z bash -c "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
docker exec build-z bash -c "$(apt_install git wget)"
docker exec build-z bash -c "$(apt_install gawk sed debhelper debmake autotools-dev fakeroot)"
docker exec build-z bash -c "$(apt_install libgtkmm-${GTKVERSION}-dev libncurses-dev)"
#
# TODO: clone by TextAdept release
#
docker exec build-z bash -c "cd /root; git clone https://github.com/orbitalquark/textadept"
docker exec build-z bash -c "cd /root; mkdir textadept_modules"
for mod in css file-diff html python rest ruby yaml # markdown yang
do
	docker exec build-z bash -c "cd /root/textadept_modules; git clone https://github.com/orbitalquark/textadept-$mod $mod"
done


cd ta
# edit_sed debian/changelog "$TAVERSION"
# cat debian/control
tar -cf /tmp/ta-debian.tar debian
echo "Copying the debian infrastructure to the container..."
docker cp /tmp/ta-debian.tar build-z:/root/textadept
cd ../ta-modules
# edit_sed debian/changelog "$TAVERSION"
tar -cf /tmp/tam-debian.tar debian
echo "Copying the debian infrastructure for the modules to the container..."
docker cp /tmp/tam-debian.tar build-z:/root/textadept_modules
cd ..

for d in textadept textadept_modules
do
	echo "In /root/$d"
	docker exec build-z bash -c "cd /root/$d; tar -xvf ta*.tar"
done
printf "\n\n"
#
# Set the version, commit and timestamp in the changelogs
#
COMMIT=$(docker exec build-z bash -c "cd /root/textadept; git log | head -1 | awk '{printf(\"%s\n\",substr(\$2,1,8))}'")
NOW=$(LC_ALL=C date '+%a, %d %b %Y %H:%m:%S %z')
echo "COMMIT=$COMMIT"
echo "NOW=$NOW"
echo "TAVERSION=$TAVERSION"
for d in textadept textadept_modules
do
	# Set the version
	docker exec build-z bash -c "cd /root/$d; sed -r -i \"/^textadept/s/[0-9].[0-9a-z.-]+/$TAVERSION/g\" debian/changelog"
	# set the comment to the short commit
	docker exec build-z bash -c "cd /root/$d; sed -r -i \"/Update /s/[0-9]+\$/$COMMIT/g\" debian/changelog"
	# Set the timestamp in the changelogs
	docker exec build-z bash -c "cd /root/$d; sed -r -i \"/^ --/s/>  [A-Z].*\$/>  $NOW/g\" debian/changelog"
done

# fix debian/control for textadept
# get the package version of the gtkmm library
GTKMM=$(docker exec build-z bash -c "apt list | awk -F/ '/^libgtkmm-[^-]*-[^d].*installed/{print \$1}'")
# make sure it is in debian/control
echo  "cd /root/textadept; sed -r -i \"s/libgtkmm-[^,]*,/${GTKMM},/g\" debian/control"
docker exec build-z bash -c "cd /root/textadept; sed -r -i \"s/libgtkmm-[^,]*,/${GTKMM},/g\" debian/control"
#
# For debugging purposes
#
for d in textadept textadept_modules
do
	printf "\n%s/debian/changelog:\n\n" $d
	docker exec build-z bash -c "cat /root/$d/debian/changelog"
	printf "\n%s/debian/control:\n\n" $d
	docker exec build-z bash -c "cat /root/$d/debian/control"
done
#
# create the module packages
#
for d in textadept textadept_modules
do
	docker exec build-z bash -c "cd /root/$d; fakeroot debian/rules ${GTK3} clean binary"
done
get_debs
