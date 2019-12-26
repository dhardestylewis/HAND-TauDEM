## HAND discretised and visualised
## Daniel Hardesty Lewis

import fiona
import rasterio
import rasterio.features
from shapely.geometry import shape, mapping
from shapely.geometry.multipolygon import MultiPolygon
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import numpy.ma as ma
import argparse

def argparser():

    parser = argparse.ArgumentParser()

    parser.add_argument("-d", "--dd", type=str, help="")
    parser.add_argument("-b", "--binmethod", type=str, help="")
#    parser.add_argument("-c", "--cmap", type=str, help="")
#    parser.add_argument("-b", "--bins", type=int, help="")
    parser.add_argument("-s", "--shapefile", type=str, help="")
    parser.add_argument("-g", "--geojson", type=str, help="")

    args = parser.parse_args()

    if not args.dd:
        parser.error('-d --dd Distance down raster')
    if not args.binmethod:
        parser.error('-b --binmethod Binning method')
#    if not args.cmap:
#        parser.error('-c --cmap Name of Matplotlib colormap')
#    if not args.bins:
#        parser.error('-b --bins Number of bins for discretization')
    if not args.shapefile:
        parser.error('-s --shapefile Output shapefile of distance down')
    if not args.geojson:
        parser.error('-g --geojson Output GeoJSON of distance down')

    return(args)

def main():

    options = argparser()

    dd = rasterio.open(options.dd)
    ddma = ma.array(dd.read(),mask=(dd.read()==dd.nodata))
    #ddmasort = np.sort(ma.array(ddma.data,mask=((ddma.mask)|(ddma.data==0.))).compressed())
    nodata = -1.
    ddmasort = np.sort(ddma.filled(fill_value=nodata).flatten())
#    nbins=options.bins
    binning = options.binmethod.split(" ")
    if binning[0] == 'lin':
        if len(binning)>1:
            bins = np.linspace(
                float(binning[1]),
                float(binning[2]),
                int(binning[3])
            )
        else:
            bins = np.linspace(0.,1.5*5.,6)
        bins = np.insert(bins,0,[nodata])
        bins = np.append(bins,ddmasort.max())
    elif binning[0] == 'log':
        if len(binning)>1:
            bins = np.logspace(
                float(binning[1]),
                float(binning[2]),
                int(binning[3])
            )[:int(binning[4])]
        else:
            bins = np.logspace(-1,3,10)[:7]
        bins = np.insert(bins,0,[nodata,0.])
        bins = np.append(bins,ddmasort.max())
    #bins = np.logspace(-1,3,10)[:7]
    #bins[len(bins)-1] = ddmasort.max()
    #bins = np.insert(bins,0,[nodata,0.])
    nbins = len(bins) - 1
#    bins = np.zeros(nbins+1)
#    bins[0] = ddmasort.min()
#    for i in range(1,nbins+1):
#        bins[i] = ddmasort[round(len(ddmasort)/float(nbins)*float(i))-1]
    ## ddmasort[round(len(ddmasort)/7.*7)-1]==ddmasort.max()==True
    #plt.hist(ddmasort,bins=bins)
    ## "<=" in the first condition below
    ##  because we have intentionally excluded 0s as nodata values
    means = np.zeros(nbins)
    #means[1] = ddmasort[(bins[1]<=ddmasort)&(ddmasort<=bins[2])].mean()
    for i in range(0,nbins):
        means[i] = ddmasort[(bins[i]<ddmasort)&(ddmasort<=bins[i+1])].mean()
    binscor = bins
#    binscor[len(binscor)-1] = bins[len(bins)-1] + 1
    digi = np.digitize(ddma.filled(fill_value=nodata),binscor,right=True)
    digi = digi.squeeze() - 1
    digiflat = digi.flatten().astype(np.float32)
    for i in range(0,nbins):
        digiidc = np.where(digi.flatten()==i)[0]
        np.put(digiflat,digiidc,np.full(digiidc.shape,means[i]))
    digirshp = digiflat.reshape(digi.shape)
    shapes = list(rasterio.features.shapes(digirshp,transform=dd.transform))
    unique_values = np.unique(digirshp)
    shp_schema = {
        'geometry': 'MultiPolygon',
        'properties': {
            'mean': 'float',
            'bin_left': 'float',
            'bin_right': 'float'
        }
    }
    vecshp = fiona.open(
        options.shapefile,
        'w',
        'ESRI Shapefile',
        shp_schema,
        dd.crs.to_string()
    )
    vecjsn = fiona.open(
        options.geojson,
        'w',
        'GeoJSON',
        shp_schema,
        dd.crs.to_string()
    )
    for i,pixel_value in enumerate(unique_values):
        polygons = [shape(geom) for geom,value in shapes if value==pixel_value]
        multipolygon = MultiPolygon(polygons)
        if i == 0:
            vecshp.write({
                'geometry': mapping(multipolygon),
                'properties': {
                    'mean': float(pixel_value),
                    'bin_left': float(bins[0]),
                    'bin_right': float(bins[0])
                }
            })
            vecjsn.write({
                'geometry': mapping(multipolygon),
                'properties': {
                    'mean': float(pixel_value),
                    'bin_left': float(bins[0]),
                    'bin_right': float(bins[0])
                }
            })
        elif i == 1:
            vecshp.write({
                'geometry': mapping(multipolygon),
                'properties': {
                    'mean': float(pixel_value),
                    'bin_left': float(bins[1]),
                    'bin_right': float(bins[1])
                }
            })
            vecjsn.write({
                'geometry': mapping(multipolygon),
                'properties': {
                    'mean': float(pixel_value),
                    'bin_left': float(bins[1]),
                    'bin_right': float(bins[1])
                }
            })
        else:
            vecshp.write({
                'geometry': mapping(multipolygon),
                'properties': {
                    'mean': float(pixel_value),
                    'bin_left': float(bins[i-1]),
                    'bin_right': float(bins[i])
                }
            })
            vecjsn.write({
                'geometry': mapping(multipolygon),
                'properties': {
                    'mean': float(pixel_value),
                    'bin_left': float(bins[i-1]),
                    'bin_right': float(bins[i])
                }
            })
    vecshp.close()
    vecjsn.close()
#    cmap = mpl.cm.get_cmap(options.cmap)
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
#    plt.savefig(options.output)
#    plt.show()

if __name__ == "__main__":
    main()

