#!/bin/sh

# We mustn't include references to Unix in libraries which can be linked
# into Xen kernels.

CMO=$(find _build/lib -name "*.cmo" | grep -v unix)
CMX=$(find _build/lib -name "*.cmx" | grep -v unix)

ALL="$CMO $CMX"
for i in $ALL
do
  echo -n "Checking $i: "
  ocamlobjinfo $i | grep Unix >/dev/null 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "OK"
  else
    echo "ERROR: Unix detected:"
    ocamlobjinfo $i
    exit 1
  fi
done

