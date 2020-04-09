# debian_ta
Infrastructure to build debian packages for TextAdept

This is the basic infrastructure I use to create the packages for Ubuntu

## Rationale

Source creates three packages for Textadept
  1. gtk
  2. nox  (== curses)
  3. common (all the Lua base)
 
 And the different 'supported' modules provided by Mitchell

The three .sh update the trees from merculrial and set the version names accordingly
