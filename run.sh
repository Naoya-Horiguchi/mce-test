#!/bin/bash

caselist=$1

make
make install

awk '{if ($3 == "on") {print $1" "$2}}' "$caselist" > /tmp/caselist
./runmcetest -t ./work/ -s ./summary/ -o ./results/ -b ./bin/ -l /tmp/caselist -r 1
