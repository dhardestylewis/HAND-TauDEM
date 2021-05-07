## Weight raster from channel heads
## Create a binary raster where 0s indicate uppermost channel heads
##  and 1s indicate other cells of the subbasin
## Daniel Hardesty Lewis

import geopandas as gpd
import rasterio as rio
from rasterio import features
import numpy.ma as ma
import argparse

def argparser():

    parser = argparse.ArgumentParser()

    parser.add_argument("-s", "--shapefile", type=str, help="Shapefile of channel heads")
    parser.add_argument("-t", "--template", type=str, help="Template raster")
    parser.add_argument("-o", "--output", type=str, help="Raster of weights")

    args = parser.parse_args()

    if not args.shapefile:
        parser.error('-s --shapefile Shapefile of channel heads not given')
    if not args.template:
        parser.error('-t --template Raster to use as template not given')
    if not args.output:
        parser.error('-o --output Name of output raster of weights not given')

    return(args)

    #shp_fn = 'Travis-Flowlines-MR-HUC120902050408_dangle.shp'
    #rst_fn = 'Travis-DEM-10m-HUC120902050408buf.tif'
    #out_fn = 'Travis-DEM-10m-HUC120902050408bufwg.tif'

def main():

    options = argparser()

    heads = gpd.read_file(options.shapefile)

    with rio.open(options.template) as rst:
        meta = rst.meta.copy()
        mask = (rst.read().squeeze()==meta['nodata'])
    meta.update(compress='lzw')

    with rio.open(options.output,'w+',**meta) as out:

        out_arr = out.read(1)

        heads['value'] = 0.0

        outma = ma.array(out_arr,mask=mask)
        outma.data[outma==meta['nodata']] = 1.0

        shapes = ((geom,value) for geom,value in zip(heads.geometry,heads.value))
        burned = features.rasterize(shapes=shapes,fill=0.0,out=outma.data,transform=out.transform)
        out.write_band(1,burned)

if __name__ == "__main__":
    main()

