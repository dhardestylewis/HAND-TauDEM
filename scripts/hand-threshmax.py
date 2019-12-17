## Correct default thresholding
## Default of 200. m^2 must be converted to the resolution of the DEM
## Daniel Hardesty Lewis

import argparse
import rasterio as rio

def argparser():

    parser = argparse.ArgumentParser()

    parser.add_argument("-a","--accumulation",type=str,help="Flow accumulation raster")
    parser.add_argument("-o","--output",type=str,help="Textfile with maximum threshold")

    args = parser.parse_args()

    if not args.accumulation:
        parser.error('-a --accumulation Flow accumulation raster not given')
    if not args.output:
        parser.error('-o --output Output textfile of maximum threshold not given')

    return(args)

def main():

    options = argparser()
    
    with rio.open(options.accumulation) as ssa:
        threshmax = ssa.read().max()
    
    with open(options.output,'w') as f:
        f.write(str(threshmax))
    
if __name__ == "__main__":
    main()

