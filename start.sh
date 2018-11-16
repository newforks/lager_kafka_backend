#!/bin/sh



# +A 8 \
exec erl \
  +P 10240000 \
  +K true \
  -name octopus@10.140.2.17 \
  +zdbbl 8192 \
  -config ./config/sys.config \
  -pa $PWD/_build/default/lib/*/ebin -setcookie XEXIWPUHUJTYKXFMMTXE
