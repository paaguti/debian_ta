# debian_ta
Infrastructure to build debian packages for TextAdept

This is the basic infrastructure I use to create the packages for Ubuntu

## Rationale

Source creates three packages for Textadept
  1. gtk
  2. common (all the Lua base)
  3. nox  (== curses)
 
 And the different 'supported' modules provided by Mitchell

CHANGELOG:

20201014: ported to the new orbitalquarks github repos.
          Building textadept-curses is *broken*
20201017: fixed building textadept-curses
          TODO: edit debian/changelog inside docker
