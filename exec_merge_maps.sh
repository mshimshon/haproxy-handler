#!/bin/bash
set -e
source ./shared_constraint_root.sh
source ./shared_variables.sh



# Clear the merged file
> "$MERGED_MAP"

# Concatenate all .map files in alphabetical order
for mapfile in "$DOMAINS_DIR"/*.map; do
    if [ -f "$mapfile" ]; then
        cat "$mapfile" >> "$MERGED_MAP"
    fi
done

echo "Merged $(ls -1 "$DOMAINS_DIR"/*.map 2>/dev/null | wc -l) map files into $MERGED_MAP"