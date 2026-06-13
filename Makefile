# heap_footprint --- build the C shim into a static lib the Pony package links.
#
# The Pony package links the shim via `use "lib:heap_footprint"` +
# `use "path:lib"`, which resolves relative to the package directory --- so the
# archive must live at heap_footprint/lib/libheap_footprint.a. Run `make`
# before compiling anything that uses this package.

PKG := heap_footprint
LIBDIR := $(PKG)/lib
LIB := $(LIBDIR)/lib$(PKG).a

CC ?= cc
AR ?= ar
CFLAGS ?= -O2 -fPIC -Wall -Wextra
PONYC ?= ponyc

.PHONY: all test clean

all: $(LIB)

$(LIB): $(PKG)/_shim.c | $(LIBDIR)
	$(CC) $(CFLAGS) -c $< -o $(LIBDIR)/_shim.o
	$(AR) rcs $@ $(LIBDIR)/_shim.o

$(LIBDIR):
	mkdir -p $(LIBDIR)

# Build and run the package's test binary.
test: all
	$(PONYC) $(PKG) -o $(PKG) -b $(PKG)_test
	./$(PKG)/$(PKG)_test

clean:
	rm -rf $(LIBDIR) $(PKG)/$(PKG)_test $(PKG)/$(PKG)_test.o
