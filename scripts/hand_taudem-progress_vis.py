## HAND-TauDEM progress visualization
## Author: Daniel Hardesty Lewis

## Import modules
import os
import argparse
import pandas as pd
import numpy as np
import geopandas as gpd
import glob
import matplotlib.pyplot as plt
import contextily as ctx


def argparser():
    ## Define input and output file locations

    parser = argparse.ArgumentParser()

    ## Path of HAND-TauDEM commands file
    parser.add_argument(
        "-c",
        "--path_hand_cmds",
        type=str,
        help="path of HAND-TauDEM commands file"
    )
    ## Base file names of HAND-TauDEM log files
    parser.add_argument(
        "-l",
        "--path_hand_logs",
        type=str,
        help="path of HAND-TauDEM log files"
    )
    ## Base file names of HUC12 catchments GIS vector files (shapefiles, etc)
    parser.add_argument(
        "-w",
        "--path_hand_watersheds",
        type=str,
        help="path of HUC12 watersheds files"
    )
    ## Path of HAND-TauDEM progress visualization image (PNG)
    parser.add_argument(
        "-i",
        "--path_hand_image",
        type=str,
        help="path of HAND-TauDEM progress visualization image"
    )
    ## Size of HAND-TauDEM progress visualization image in units
    parser.add_argument(
        "-u",
        "--units",
        type=int,
        help="size of HAND-TauDEM progress visualization image in units"
    )
    ## Size of HAND-TauDEM progress visualization image in units
    parser.add_argument(
        "-d",
        "--working_dir",
        type=str,
        help="path of working directory"
    )
    ## Output vector image of visualization
    parser.add_argument(
        "-g",
        "--path_hand_gdf",
        type=str,
        help="output vector image of visualization"
    )

    args = parser.parse_args()

    ## Check that required inputs have been defined
    if not args.path_hand_cmds:
        parser.error('-c --path_hand_cmds HAND commands file needed')
    if not args.path_hand_logs:
        parser.error('-l --path_hand_logs HAND log file names needed')
    if not args.path_hand_watersheds:
        parser.error('-c --path_hand_watersheds HUC12 catchment file names')
    if not args.path_hand_image:
        parser.error('-i --path_hand_image HAND progress vis image needed')
    if not args.working_dir:
        parser.error('-d --working_dir Parent directory of HAND data')
    if not args.path_hand_gdf:
        parser.error('-g --path_hand_gdf Output vector image of visualization')

    return(args)


def visualize(gdfs,edgecolors=False,units=40,col='pct_finished'):
    figsize = (
        units,
        gdfs[0].shape[1] / gdfs[0].shape[0] * units
    )
    f, ax = plt.subplots(figsize = figsize)
    if edgecolors==False:
        edgecolors = ['k'] * len(gdfs)
    for i, gdf in enumerate(gdfs):
        gdf.to_crs(epsg=3857).plot(
            ax = ax,
            figsize = figsize,
            alpha = .5,
            edgecolor = edgecolors[i],
            column = col,
            cmap = 'cividis',
            legend = True
        )
    ctx.add_basemap(ax)
    plt.show()
    f.savefig(args.path_hand_image)


def main():

    global args

    args = argparser()

    oldpwd = os.getcwd()
    os.chdir(args.working_dir)

    with open(args.path_hand_cmds) as f:
        content = f.readlines()
    content = [x.strip() for x in content]
    content.insert(0,'touch')

    logfiles = glob.glob(os.path.join('*','*',args.path_hand_logs))
    logs = [
        pd.read_csv(log)
        for log
        in logfiles
    ]
    last_cmds = [
        log.loc[0,'last_cmd']
        for log
        in logs
    ]

    pct_finished = [
        np.array([
            i
            for i, word
            in enumerate(content)
            if word.startswith(lastcmd)
        ]).max()
        for lastcmd
        in last_cmds
    ]
    pct_finished = (np.array(pct_finished) + 1) / len(content)

    catchments = glob.glob(os.path.join('*','*',args.path_hand_watersheds))
    catchments_gpd = [gpd.read_file(catchment) for catchment in catchments]
    hucs = gpd.GeoDataFrame(
        [
            catchment.dissolve(by = ['HUC12']).iloc[0]
            for catchment
            in catchments_gpd
        ],
        crs = catchments_gpd[0].crs
    )

    hucs['pct_finished'] = pct_finished
    hucs['logfiles'] = logfiles

    hucs.to_file(args.path_hand_gdf)

    if args.units is not None:
        visualize([hucs],edgecolors=['k'],units=args.units)
    else:
        visualize([hucs],edgecolors=['k'])

    os.chdir(oldpwd)


if __name__ == "__main__":

    main()


