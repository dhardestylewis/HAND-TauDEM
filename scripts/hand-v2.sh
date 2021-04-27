#!/bin/bash

pitremove -z $1 -fel demfel.tif
dinfflowdir -fel demfel.tif -ang demang.tif -slp demslp.tif
d8flowdir -fel demfel.tif -p demp.tif -sd8 demsd8.tif

aread8 -p demp.tif -ad8 demad8.tif
areadinf -ang demang.tif -sca demsca.tif
slopearea -slp demslp.tif -sca demsca.tif -sa demsa.tif
d8flowpathextremeup -p demp.tif -sa demsa.tif -ssa demssa.tif
threshold -ssa demssa.tif -src demsrc.tif -thresh 38.7

streamnet -fel demfel.tif -p demp.tif -ad8 demad8.tif -src demsrc.tif -ord demord.tif -tree demtree.dat -coord demcoord.dat -net demnet.shp -w demw.tif

python3 hand-heads.py --network demnet.shp --output dem_dangle.shp
python3 hand-weights.py --shapefile dem_dangle.shp --template demfel.tif --output demwg.tif

aread8 -p demp.tif -ad8 demssa.tif -wg demwg.tif
threshold -ssa demssa.tif -src demsrc.tif -thresh 22.4

dinfdistdown -ang demang.tif -fel demfel.tif -src demsrc.tif -dd $2
