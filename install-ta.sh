#!/bin/bash

function usage () {
  echo "$(basename $0) <version>"
  echo " for example: $(basename $0) 11.0-alpha1"
}

function main () {
[ $# -eq 1 ] || usage
[ $# -eq 1 ] || return
OK=$(echo "$1" | grep -E '[0-9]+\.[0-9a-z.-]+'| wc -l)
[ $OK -eq 1 ]  || usage
[ $OK -eq 1 ]  || return

  VERSION=$1

  sudo dpkg -i textadept-gtk_${VERSION}_amd64.deb \
    textadept-common_${VERSION}_all.deb \
    textadept-modules-*_${VERSION}_*.deb
}

main $*
