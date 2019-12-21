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

    basindd = rasterio.open(options.dd)
    basinddma = ma.array(basindd.read(),mask=(basindd.read()==basindd.nodata))
    #basinddmasort = np.sort(ma.array(basinddma.data,mask=((basinddma.mask)|(basinddma.data==0.))).compressed())
    basinddmasort = np.sort(basinddma.filled(fill_value=-1.).flatten())
#    nbins=options.bins
    basinddmasortbinsnodata = -1.
    binning = options.binmethod.split(" ")
    if binning[0] == 'lin':
        if len(binning)>1:
            basinddmasortbins = np.linspace(
                float(binning[1]),
                float(binning[2]),
                int(binning[3])
            )
        else:
            basinddmasortbins = np.linspace(0.,1.5*5.,6)
        basinddmasortbins = np.insert(basinddmasortbins,0,[basinddmasortbinsnodata])
        basinddmasortbins = np.append(basinddmasortbins,basinddmasort.max())
    elif binning[0] == 'log':
        if len(binning)>1:
            basinddmasortbins = np.logspace(
                float(binning[1]),
                float(binning[2]),
                int(binning[3])
            )[:int(binning[4])]
        else:
            basinddmasortbins = np.logspace(-1,3,10)[:7]
        basinddmasortbins = np.insert(basinddmasortbins,0,[basinddmasortbinsnodata,0.])
        basinddmasortbins = np.append(basinddmasortbins,basinddmasort.max())
    #basinddmasortbins = np.logspace(-1,3,10)[:7]
    #basinddmasortbins[len(basinddmasortbins)-1] = basinddmasort.max()
    #basinddmasortbins = np.insert(basinddmasortbins,0,[basinddmasortbinsnodata,0.])
    nbins = len(basinddmasortbins)-1
#    basinddmasortbins = np.zeros(nbins+1)
#    basinddmasortbins[0] = basinddmasort.min()
#    for i in range(1,nbins+1):
#        basinddmasortbins[i] = basinddmasort[round(len(basinddmasort)/float(nbins)*float(i))-1]
    ## basinddmasort[round(len(basinddmasort)/7.*7)-1]==basinddmasort.max()==True
    #plt.hist(basinddmasort,bins=basinddmasortbins)
    ## "<=" in the first condition below
    ##  because we have intentionally excluded 0s as nodata values
    basinddmasortbinsmean = np.zeros(nbins)
    #basinddmasortbinsmean[1] = basinddmasort[(basinddmasortbins[1]<=basinddmasort)&(basinddmasort<=basinddmasortbins[2])].mean()
    for i in range(0,nbins):
        basinddmasortbinsmean[i] = basinddmasort[(basinddmasortbins[i]<=basinddmasort)&(basinddmasort<basinddmasortbins[i+1])].mean()
    basinddmasortbinscor = basinddmasortbins
    basinddmasortbinscor[len(basinddmasortbinscor)-1] = basinddmasortbins[len(basinddmasortbins)-1]+1
    basinddmadigi = np.digitize(basinddma.filled(fill_value=-1.),basinddmasortbinscor,right=False).squeeze()-1
    basinddmadigiflat = basinddmadigi.flatten().astype(np.float32)
    for i in range(0,nbins):
        basinddmadigiidc = np.where(basinddmadigi.flatten()==i)[0]
        np.put(basinddmadigiflat,basinddmadigiidc,np.full(basinddmadigiidc.shape,basinddmasortbinsmean[i]))
    basinddmadigirshp = basinddmadigiflat.reshape(basinddmadigi.shape)
    shapes = list(rasterio.features.shapes(basinddmadigirshp,transform=basindd.transform))
    unique_values = np.unique(basinddmadigirshp)
    shp_schema = {
        'geometry': 'MultiPolygon',
        'properties': {
            'mean': 'float',
            'bin_left': 'float',
            'bin_right': 'float'
        }
    }
    vecshp = fiona.open(options.shapefile,'w','ESRI Shapefile', shp_schema, basindd.crs.to_string())
    vecjsn = fiona.open(options.geojson,'w','GeoJSON', shp_schema, basindd.crs.to_string())
    for pixel_value in unique_values:
        polygons = [shape(geom) for geom,value in shapes if value==pixel_value]
        multipolygon = MultiPolygon(polygons)
        vecshp.write({
            'geometry': mapping(multipolygon),
            'properties': {
                'mean':float(pixel_value),
                'bin_left': float(basinddmasortbins[i]),
                'bin_right': float(basinddmasortbins[i+1])
            }
        })
        vecjsn.write({
            'geometry': mapping(multipolygon),
            'properties': {
                'mean':float(pixel_value),
                'bin_left': float(basinddmasortbins[i]),
                'bin_right': float(basinddmasortbins[i+1])
            }
        })
    vecshp.close()
    vecjsn.close()
#    cmap = mpl.cm.get_cmap(options.cmap)
#    cmapdiscretear = cmap(np.linspace(0,1,nbins))
#    for i in range(1,nbins-1):
#        cmapdiscretear[i] = np.append(cmap.colors[int(round(float(len(cmap.colors))/(basinddmasortbinsmean[nbins-1]-basinddmasortbinsmean[0])*np.cumsum(np.diff(basinddmasortbinsmean))[i-1]))-1],1.)
#    cmapdiscretear = np.insert(cmapdiscretear,0,[0.,0.,0.,0.],axis=0)
#    cmapdiscrete = mpl.colors.ListedColormap(cmapdiscretear)
#    fig,ax = plt.subplots()
#    cax = ax.imshow(basinddmadigi,interpolation='none',cmap=cmapdiscrete)
#    ax.set_title('Vertical distance down to nearest drainage')
#    cbar = fig.colorbar(cax)
#    basinddmasortbinsstr = ['{:.2f}'.format(x) for x in basinddmasortbins.tolist()]
#    cbar.ax.set_yticklabels([s + ' m' for s in basinddmasortbinsstr])
#    plt.savefig(options.output)
#    plt.show()

if __name__ == "__main__":
    main()

