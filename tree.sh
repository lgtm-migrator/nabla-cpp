#!/bin/sh

python3 /usr/bin/scons --tree=prune
#python3 /usr/bin/scons --tree=prune binaries

python3 /usr/bin/scons --tree=derived,prune target -n | ./scons2dot.py --save --outfile deps.pdf
