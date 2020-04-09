#!/bin/bash

[ $# -eq 1 ] || echo "$(basename $0) <version> version like 10.8-1"
[ $# -eq 1 ] || exit
OK=$(echo "$1" | grep -E '[0-9]+\.[0-9a-z.-]+'| wc -l)
[ $OK -eq 1 ]  || echo "$(basename $0) <version> version like 10.8-1"
[ $OK -eq 1 ]  || exit

VERSION=$1

rm -vf textadept-gtk_${VERSION}_amd64.deb \
  textadept-nox_${VERSION}_amd64.deb \
  textadept-common_${VERSION}_all.deb \
  textadept-modules-*_${VERSION}_*.deb \
  textadept*_${VERSION}_*.ddeb
