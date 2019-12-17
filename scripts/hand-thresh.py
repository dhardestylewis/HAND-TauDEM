## Correct default thresholding
## Default of 200. m^2 must be converted to the resolution of the DEM
## Daniel Hardesty Lewis

import argparse
import rasterio as rio
from rasterio.warp import calculate_default_transform,reproject,Resampling

def argparser():

    parser = argparse.ArgumentParser()

    parser.add_argument("-r","--resolution",type=str,help="Resolution raster")
    parser.add_argument("-o","--output",type=str,help="Textfile with threshold")

    args = parser.parse_args()

    if not args.resolution:
        parser.error('-r --resolution Resolution raster not given')
    if not args.output:
        parser.error('-o --output Output textfile of threshold not given')

    return(args)

def main():

    options = argparser()

    dst_crs = 'EPSG:6343'
    
    with rio.open(options.resolution) as fel:
        transform,width,height = calculate_default_transform(fel.crs,dst_crs,fel.width,fel.height,*fel.bounds)
        kwargs = fel.meta.copy()
        kwargs.update({
            'crs':dst_crs,
            'transform':transform,
            'width':width,
            'height':height
        })
    
        with rio.open('demfel_utm14.tif','w',**kwargs) as dst:
            reproject(
                source = rio.band(fel,1),
                destination = rio.band(dst,1),
                src_transform = fel.transform,
                src_crs = fel.crs,
                dst_transform = transform,
                dst_crs = dst_crs,
                resampling = Resampling.nearest
            )
            dst.close()
    
    with rio.open('demfel_utm14.tif') as fel_utm14:
        thresh = 200./(fel_utm14.res[0]*fel_utm14.res[1])
    
    with open(options.output,'w') as f:
        f.write(str(thresh))
    
if __name__ == "__main__":
    main()

