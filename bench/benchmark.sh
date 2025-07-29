#!/usr/bin/bash

file=${1:-test/medium.tdms}

poop "python3 bench/metadata.py ${file}" "./zig-out/bin/tdms-example ${file}"
