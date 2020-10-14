#!/bin/bash

pitremove -z $1 -fel demfel.tif
dinfflowdir -fel demfel.tif -ang demang.tif -slp demslp.tif
## TODO: see about replacing all instances of d8 with dinf
d8flowdir -fel demfel.tif -p demp.tif -sd8 demsd8.tif
aread8 -p demp.tif -ad8 demad8.tif -nc
areadinf -ang demang.tif -sca demsca.tif -nc

## Skeleton
slopearea -slp demslp.tif -sca demsca.tif -sa demsa.tif
## TODO: d8flowpathextremeup takes input ultimately from areadinf not aread8
## TODO: possibly requires lumping step before d8flowpathextremeup
d8flowpathextremeup -p demp.tif -sa demsa.tif -ssa demssa.tif -nc
#python3 hand-thresh.py --resolution demfel.tif --output demthresh.txt
#threshold -ssa demssa.tif -src demsrc.tif -thresh $(cat demthresh.txt)
## TODO: Possibly re-incorporate hand-thresh.py or actually do a parameter sweep / sensitivity analysis
threshold -ssa demssa.tif -src demsrc.tif -thresh 500.0

streamnet -fel demfel.tif -p demp.tif -ad8 demad8.tif -src demsrc.tif -ord demord.tif -tree demtree.dat -coord demcoord.dat -net demnet.shp -w demw.tif -sw

connectdown -p demp.tif -ad8 demad8.tif -w demw.tif -o outlets.shp -od movedoutlets.shp

python3 hand-heads.py --network demnet.shp --output dangles.shp
python3 hand-weights.py --shapefile dangles.shp --template demfel.tif --output demwg.tif
aread8 -p demp.tif -ad8 demssa.tif -o outlets.shp -wg demwg.tif -nc

python3 hand-threshmin.py --resolution demfel.tif --output demthreshmin.txt
python3 hand-threshmax.py --accumulation demssa.tif --output demthreshmax.txt
dropanalysis -ad8 demad8.tif -p demp.tif -fel demfel.tif -ssa demssa.tif -o outlets.shp -drp demdrp.txt -par $(cat demthreshmin.txt) $(cat demthreshmax.txt) 10 0
threshold -ssa demssa.tif -src demsrc.tif -thresh $(tail -n 1 demdrp.txt | awk '{print $NF}')

dinfdistdown -ang demang.tif -fel demfel.tif -src demsrc.tif -wg demwg.tif -dd $2 -m ave v -nc

python3 hand-vis.py --input $2 --binmethod 'lin' --raster $3 --shapefile $4 --geojson $5
