## Points from stream network produced by TauDEM's streamnet
## Daniel Hardesty Lewis

import geopandas as gpd
import argparse

def argparser():

    parser = argparse.ArgumentParser()

    parser.add_argument("-b", "--boundary", type=str, help="")
    parser.add_argument("-o", "--output", type=str, help="")

    args = parser.parse_args()

    if not args.boundary:
        parser.error('-b --boundary Boundary shapefile to buffer')
    if not args.output:
        parser.error('-o --output Output shapefile of buffered boundary')

    return(args)

def main():

    options = argparser()

    awash = gpd.read_file(options.boundary)
    awash_buffer = awash
    awash_buffer['geometry'] = awash.to_crs({'init': 'epsg:32637'}).buffer(100.).to_crs(awash.crs)
    awash_buffer.to_file(options.output)

if __name__ == "__main__":
    main()

