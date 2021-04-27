## Outlet of single HUC from pixel with highest D8 area (from TauDEM aread8)
## Daniel Hardesty Lewis

import rasterio
import numpy as np
from shapely import geometry
import geopandas as gpd
import argparse

def argparser():
    
    parser = argparse.ArgumentParser()

    parser.add_argument("-a", "--aread8", type=str, help="")
    parser.add_argument("-o", "--output", type=str, help="")
    
    args = parser.parse_args()

    if not args.aread8:
        parser.error('-a --aread8 D8 area raster from TauDEM aread8 function')
    if not args.output:
        parser.error('-o --output Output shapefile of outlet')

    return(args)

def main():

    options = argparser()

    ad8 = rasterio.open(options.aread8)

    outlets = gpd.GeoDataFrame(
        geometry = [geometry.Point(ad8.xy(*np.unravel_index(
            ad8.read().argmax(),
            ad8.shape
        )))],
        crs = ad8.crs
    )

    outlets.to_file(options.output)

if __name__ == "__main__":
    main()
