## HAND discretised and visualised
## Daniel Hardesty Lewis

import argparse
import numpy as np
import numpy.ma as ma
import rasterio
import rasterio.features
from shapely.geometry import shape, mapping
from shapely.geometry.multipolygon import MultiPolygon
import fiona
#import matplotlib as mpl
#import matplotlib.pyplot as plt

def argparser():

    parser = argparse.ArgumentParser()

    parser.add_argument("-i", "--input", type=str, help="")
    parser.add_argument("-b", "--binmethod", type=str, help="")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-r", "--raster", type=str, help="")
    group.add_argument("-s", "--shapefile", type=str, help="")
    group.add_argument("-g", "--geojson", type=str, help="")
#    parser.add_argument("-c", "--cmap", type=str, help="")

    args = parser.parse_args()

    if not args.input:
        parser.error('-r --raster Distance down raster')
    if not args.binmethod:
        parser.error('-b --binmethod Binning method')
    if not args.raster and not args.shapefile and not args.geojson:
        parser.error('-r --raster OR -s --shapefile OR -g --geojson output req')
#    if not args.shapefile:
#        parser.error('-s --shapefile Output shapefile of distance down')
#    if not args.geojson:
#        parser.error('-g --geojson Output GeoJSON of distance down')
#    if not args.cmap:
#        parser.error('-c --cmap Name of Matplotlib colormap')

    return(args)

def digi(nodata,raster):

    def np_space():
        bins = binning[0](
            float(binning[1]),
            float(binning[2]),
            num = int(binning[3]),
            dtype = np.float
        )
        return(bins)
    
    binning = args.binmethod.split(" ")
    if binning[0] == 'lin':
        if len(binning)>1:
            binning[0] = np.linspace
            bins = np_space()
        else:
            bins = np.linspace(0.,1./3.28084*20.,num=21,dtype=np.float)
    elif binning[0] == 'log':
        if len(binning)>1:    
            binning[0] = np.logspace
            bins = np_space()
        else:
            bins = np.logspace(np.log10(1./3.28084),np.log10(20./3.28084),num=20,dtype=np.float)
        bins = np.insert(bins,0,[0.])
    bins = np.append(bins,nodata)
    print(bins)

    digi = np.digitize(raster.filled(fill_value=int(nodata)),bins,right=True)
    digi = digi.squeeze().astype(np.uint16)
    digi[digi==21] = int(nodata)
    print(digi)
    print(np.unique(digi))

    return(bins, digi)

# TODO: Output digi as raster
def output_raster(profile,nodata,digi):

    ## 1 band, smallest necessary dtype, LZW compression
    profile.update(
        dtype=rasterio.uint16,
        count=1,
        compress='lzw',
        nodata=int(nodata)
    )
    print(profile)

    with rasterio.open(args.raster, 'w', **profile) as dst:
        dst.write(digi.astype(rasterio.uint16), 1)

def output_vector(crs,digi,transform,bins):

    def fiona_open():
        vec = fiona.open(
            args.shapefile,
            'w',
            driver,
            shp_schema,
            crs
        )
        return(vec)

    def vec_for():
    
        def vec_write(vecvec):
            vecvec.write({
                'geometry': multipolygon,
                'properties': {
                    'bin_left': bin_left,
                    'bin_right': bin_left
                }
            })
    
        for i,pixel_value in enumerate(uniq_val_subset):
            polygons = [shape(geom) for geom,value in shapes if value==pixel_value]
            multipolygon = mapping(MultiPolygon(polygons))
            bin_left = bins[i-di]
            bin_right = bins[i]
            if args.shapefile:
                vec_write(vec['ESRI Shapefile'])
            if args.geojson:
                vec_write(vec['GeoJSON'])

    shp_schema = {
        'geometry': 'MultiPolygon',
        'properties': {
            'bin_left': 'float',
            'bin_right': 'float'
        }
    }

    vec = {}
    if args.shapefile:
        driver = 'ESRI Shapefile'
        vec[driver] = fiona_open()
    if args.geojson:
        driver = 'GeoJSON'
        vec[driver] = fiona_open()

    shapes = list(rasterio.features.shapes(digi,transform=transform))
    uniq_val = np.unique(digi)

    uniq_val_subset = uniq_val[:1]
    di = 0
    vec_for()

    uniq_val_subset = uniq_val[2:-1]
    di = 1
    vec_for()

    uniq_val_subset = uniq_val[-1:]
    di = 0
    vec_for()

    if args.shapefile:
        vec['ESRI Shapefile'].close()
    if args.geojson:
        vec['GeoJSON'].close()

#def output_png():
#    cmap = mpl.cm.get_cmap(args.cmap)
#    cmapdiscretear = cmap(np.linspace(0,1,nbins))
#    for i in range(1,nbins-1):
#        cmapdiscretear[i] = np.append(cmap.colors[int(round(float(len(cmap.colors))/(means[nbins-1]-means[0])*np.cumsum(np.diff(means))[i-1]))-1],1.)
#    cmapdiscretear = np.insert(cmapdiscretear,0,[0.,0.,0.,0.],axis=0)
#    cmapdiscrete = mpl.colors.ListedColormap(cmapdiscretear)
#    fig,ax = plt.subplots()
#    cax = ax.imshow(digi,interpolation='none',cmap=cmapdiscrete)
#    ax.set_title('Vertical distance down to nearest drainage')
#    cbar = fig.colorbar(cax)
#    binsstr = ['{:.2f}'.format(x) for x in bins.tolist()]
#    cbar.ax.set_yticklabels([s + ' m' for s in binsstr])
#    plt.savefig(args.output)
#    plt.show()

def main():

    global args

    args = argparser()

    with rasterio.open(args.input) as src:
        profile = src.profile
        crs = src.crs.to_string()
        transform = src.transform
        raster = ma.array(src.read(),mask=(src.read()==src.nodata))
    print(raster)
    print(np.unique(raster))

    nodata = 65535.

    binned, digitised = digi(nodata,raster)

    if args.raster:
        output_raster(profile,nodata,digitised)
    if args.shapefile or args.geojson:
        output_vector(crs,digitised,transform,binned)

if __name__ == "__main__":
    main()

