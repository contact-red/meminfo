# heap_footprint --- the C shim (heap_footprint/shim.c) is compiled and linked
# automatically by ponyc; there is nothing to pre-build. The shim needs the
# runtime's pony.h, located via the `use "cinclude:..."` line in
# heap_footprint.pony --- update that path for your toolchain. Find it with:
#
#   echo "$(dirname "$(dirname "$(readlink -f "$(which ponyc)")")")/include"

PKG := heap_footprint
PONYC ?= ponyc

.PHONY: test clean

# Build and run the package's test binary.
test:
	$(PONYC) $(PKG) -o $(PKG) -b $(PKG)_test
	./$(PKG)/$(PKG)_test

clean:
	rm -f $(PKG)/$(PKG)_test $(PKG)/$(PKG)_test.o
