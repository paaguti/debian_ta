#!/usr/bin/env make -f

PREFIX ?= /usr/local
bin_dir = $(PREFIX)/bin
data_dir = $(PREFIX)/share/textadept
XDG_DATA_DIR ?= $(PREFIX)/share/applications
PIXMAPS_DIR ?= $(PREFIX)/share/pixmaps
INSTALL=install -o root -g root

install-common: | core docs lexers init.lua LICENSE modules themes
	$(INSTALL) -m 0755 -d $(DESTDIR)$(data_dir)/src/lua/src $(DESTDIR)$(PIXMAPS_DIR)
	cp -rL $| $(DESTDIR)$(data_dir)
	cd $(DESTDIR)$(PIXMAPS_DIR); ln -sf ../textadept/core/images/ta_48x48.png textadept.png
	cd $(DESTDIR)$(PIXMAPS_DIR); ln -sf ../textadept/core/images/textadept.svg
	#
	# Install Lua symbol and header files
	#
	$(INSTALL) -m 0644 src/lua.sym $(DESTDIR)$(data_dir)/src
	$(INSTALL) -m 0644 src/lua/src/lua*.h $(DESTDIR)$(data_dir)/src/lua/src
	$(INSTALL) -m 0644 src/lua/src/lauxlib.h $(DESTDIR)$(data_dir)/src/lua/src

install-gtk: textadept
	$(INSTALL) -m 0755 -d $(DESTDIR)$(bin_dir) $(DESTDIR)$(data_dir) $(DESTDIR)$(XDG_DATA_DIR)
	$(INSTALL) -m 0755 $^ $(DESTDIR)$(data_dir)
	cd $(DESTDIR)$(bin_dir); ln -sf $(data_dir)/$^
	$(INSTALL) -m 0644 src/$^.desktop $(DESTDIR)$(XDG_DATA_DIR)

install-curses: textadept-curses |
	$(INSTALL) -m 0755 -d $(DESTDIR)$(bin_dir) $(DESTDIR)$(data_dir) $(DESTDIR)$(XDG_DATA_DIR)
	$(INSTALL) -m 0755 $^ $(DESTDIR)$(data_dir)
	cd $(DESTDIR)$(bin_dir); ln -sf $(data_dir)/$^
	$(INSTALL) -m 0644 src/$^.desktop $(DESTDIR)$(XDG_DATA_DIR)
