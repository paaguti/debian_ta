#!/bin/bash

function edit_sed() {
  #
  # get the latest changeset from the log
  #
  #   CHGSET=`git log 1 | awk -F: '/changeset/{print $2}' | awk '{$1=$1}1'`
  CHGSET=`git log -1 | awk '/^commit/ {print $2}'`
  #
  # Edit the changelog
  #
  sed -i -E "/^textadept/s/[0-9]+\.[0-9a-z.-]+/$2/
/Update /s/[0-9]+$/$CHGSET/
/^ --/s/>  [A-Z].*$/>  `LC_ALL=C date '+%a, %d %b %Y %H:%m:%S %z'`/" $1
}

[ $# -eq 1 ] || echo "$(basename $0) <version> version like 10.8-1"
[ $# -eq 1 ] || exit
OK=$(echo "$1" | grep -E '[0-9]+\.[0-9a-z.-]+'| wc -l)
[ $OK -eq 1 ]  || echo "$(basename $0) <version> version like 10.8-1"
[ $OK -eq 1 ]  || exit
VERSION="$1"
cd textadept
fakeroot debian/rules clean
git pull
edit_sed debian/changelog "$VERSION"
fakeroot debian/rules GTK3=1 clean binary
fakeroot debian/rules GTK3=1 clean
cd ../textadept_modules
fakeroot debian/rules clean
git pull
edit_sed debian/changelog "$VERSION"
fakeroot debian/rules GTK3=1 clean binary
fakeroot debian/rules GTK3=1 clean
cd ..
