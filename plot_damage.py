import os
from matplotlib.patches import Rectangle
from matplotlib.collections import PatchCollection
import matplotlib.pyplot as plt
import mpmplotter
import mpmplotter.load
import mpmplotter.plot
from matplotlib import cm

plt.style.use("seaborn-paper")
plt.rc('font', family='serif', serif='Times')
# plt.rc('text', usetex=True)
plt.rc('xtick', labelsize=8)
plt.rc('ytick', labelsize=8)
plt.rc('axes', labelsize=8)
plt.rcParams['figure.constrained_layout.use'] = True


top_dir = "./data/"
flist = os.listdir(top_dir)
# flist = ["output-CRYO-0.25-800.0-0.8"]

for fname in flist:
    folder_name = "{}/{}".format(top_dir,fname)
    print(fname)
    data = mpmplotter.load.load_folder("{}/".format(folder_name))
    offset = 2
    dpi = 100
    h = data["settings"]["RESOLUTION"]
    d_width = data["settings"]["DOMAIN-SIZE"][0]
    d_height = data["settings"]["DOMAIN-SIZE"][1] - (offset * h)
    d_width = 3000
    ratio = d_height / d_width
    # width = 10
    width = 3.487*2
    height = width * ratio
    scale = 10
    def transform(df):
        # coord_0 = df["coord_x"] - df["disp_x"]
        # df["coord_x"] = coord_0 +  df["disp_x"] * 0
        # coord_0 = df["coord_y"] - df["disp_y"]
        # df["coord_y"] = coord_0 +  df["disp_y"] * 0
        # print("max {} min {}".format(df["disp_x"].max(),df["disp_x"].min()))
        df["coord_y"] -= (offset * h)
        return df
    fig = plt.figure(figsize=(width,height),dpi=dpi)
    colour_name = "damage"
    # colour_name = "disp_x"
    for i in [-1]:
        p = mpmplotter.plot.plot(data,i,colour_name=colour_name,extract_vals=["disp_x","disp_y"],df_transform=transform)
        water_height = data["settings"]["OCEAN-HEIGHT"] - (h * offset)
        patch = Rectangle(xy=(0,0),
                          width=d_width,
                          height=water_height,
                          fill="light blue",
                          hatch="x",
                          zorder=-5)
        ax = plt.gca()
        ax.add_patch(patch)
        plt.xlim([0,d_width])
        plt.ylim([0,d_height])
        # cmap = cm.get_cmap(None, 10)
        # p.set_cmap(cmap)
        # p.set_clim([-0.3,0.8])
        p.set_clim([0,1])
        # plt.colorbar(p)
        plt.xlabel("(m)")
        plt.ylabel("(m)")
        plt.savefig("outframes/frame_{}_{}.png".format(fname,i))
        plt.savefig("outframes/frame_{}_{}.pdf".format(fname,i))

# def wrapper(x):
#         get_plot(x[0],x[1])
# if __name__ == '__main__':
#     with Pool(16) as p:
#         p.map(wrapper, enumerate(files_csvs))
plt.close("all")
plt.show()
