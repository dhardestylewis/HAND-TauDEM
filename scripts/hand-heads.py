## Points from stream network produced by TauDEM's streamnet
## Daniel Hardesty Lewis

import geopandas as gpd
from shapely.geometry import Point
import argparse

def argparser():

    parser = argparse.ArgumentParser()

    parser.add_argument("-n", "--network", type=str, help="")
    parser.add_argument("-o", "--output", type=str, help="")

    args = parser.parse_args()

    if not args.network:
        parser.error('-n --network Stream network shapefile from TauDEM streamnet')
    if not args.output:
        parser.error('-o --output Output shapefile of channel heads')

    return(args)

def main():

    options = argparser()

    net = gpd.read_file(options.network)

    ends = net[net['USLINKNO1']==-1]
    for i in range(len(ends)):
        ends['geometry'].iloc[i] = Point(ends.iloc[i]['geometry'].coords[len(ends.iloc[i]['geometry'].coords.xy[0])-1])

    ends.to_file(options.output)

if __name__ == "__main__":
    main()
