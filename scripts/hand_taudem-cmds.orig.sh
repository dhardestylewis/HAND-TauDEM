CONDA_INITIALIZE 'hand-libgdal'
pitremove -z $argument -fel demfel.tif &
dinfflowdir -fel demfel.tif -ang demang.tif -slp demslp.tif &
d8flowdir -fel demfel.tif -p demp.tif -sd8 demsd8.tif &
aread8 -p demp.tif -ad8 demad8.tif -nc &
areadinf -ang demang.tif -sca demsca.tif -nc &
slopearea -slp demslp.tif -sca demsca.tif -sa demsa.tif &
d8flowpathextremeup -p demp.tif -sa demsa.tif -ssa demssa.tif -nc &
#python3 $PATH_HAND_PYS/hand-thresh.py --resolution demfel.tif --output demthresh.txt
threshold -ssa demssa.tif -src demsrc.tif -thresh 500.0 & #-thresh $(cat demthresh.txt)
streamnet -fel demfel.tif -p demp.tif -ad8 demad8.tif -src demsrc.tif -ord demord.tif -tree demtree.dat -coord demcoord.dat -net demnet.shp -w demw.tif -sw &
CONDA_ACTIVATE 'hand-rasterio'
python3 $PATH_HAND_PYS/hand-tail.py --aread8 demad8.tif --output outlets.shp &
python3 $PATH_HAND_PYS/hand-heads.py --network demnet.shp --output dangles.shp &
python3 $PATH_HAND_PYS/hand-weights.py --shapefile dangles.shp --template demfel.tif --output demwg.tif &
CONDA_ACTIVATE 'hand-libgdal'
aread8 -p demp.tif -ad8 demssa.tif -o outlets.shp -wg demwg.tif -nc &
CONDA_ACTIVATE 'hand-rasterio'
python3 $PATH_HAND_PYS/hand-threshmin.py --resolution demfel.tif --output demthreshmin.txt &
python3 $PATH_HAND_PYS/hand-threshmax.py --accumulation demssa.tif --output demthreshmax.txt &
CONDA_ACTIVATE 'hand-libgdal'
dropanalysis -ad8 demad8.tif -p demp.tif -fel demfel.tif -ssa demssa.tif -o outlets.shp -drp demdrp.txt -par $(cat demthreshmin.txt) $(cat demthreshmax.txt) 10 0 &
threshold -ssa demssa.tif -src demsrc.tif -thresh $(tail -n 1 demdrp.txt | awk '{print $NF}') &
dinfdistdown -ang demang.tif -fel demfel.tif -src demsrc.tif -wg demwg.tif -dd "${filename}dd.tif" -m ave v -nc &
CONDA_ACTIVATE 'hand-rasterio'
python3 $PATH_HAND_PYS/hand-vis.py --input "${filename}dd.tif" --binmethod 'lin' --raster "${filename}dd-vis.tif" --shapefile "${filename}dd-vis.shp" --geojson "${filename}dd-vis.json" &
: &
CONDA_DEACTIVATE
