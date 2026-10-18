import matplotlib as mpl
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.patches import Rectangle
from matplotlib.collections import PatchCollection
from matplotlib import cm
import re
import os
import json
import numpy as np
import pandas as pd
import json
import sys
from vtk import vtkUnstructuredGridReader
from vtk.util import numpy_support as VN
from vtk.util.numpy_support import vtk_to_numpy, numpy_to_vtk
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.patches import Rectangle
from matplotlib.collections import PatchCollection
from matplotlib import cm
from multiprocessing import Pool



top_dir = "./data/"
# top_dir = "/mnt/c/Temp/"
output_regex = re.compile("output-*")
output_list = list(filter(output_regex.match,os.listdir(top_dir)))
output_list.sort()
if len(output_list) > 1:
    for i,out in enumerate(output_list):
        print("{}: {}".format(i,out))
    output_dir = "{}./{}/".format(top_dir,output_list[int(input())])
else:
    output_dir = "{}./{}/".format(top_dir,output_list[0])


fig,(ax1,ax2) = plt.subplots(2,1)


ax_conv_residual = ax1
ax_conv_damage = ax1.twinx()
ax_conv_damage.set_ylabel("Plastic strain evolution")
ax_conv_residual.set_xlabel("Iterations")
ax_conv_residual.set_ylabel("Convergence criteria")

ax_de_residual = ax2
ax_de_damage = ax2.twinx()
ax_de_residual.set_xlabel("Time (s)")
ax_de_residual.set_ylabel("Resiudal")
ax_de_damage.set_ylabel("Mass-damage")

def plot_conv():
    # ax.clear()
    ax = ax_conv_residual
    ax_damage = ax_conv_damage
    ax_damage.clear()
    ax.clear()
    df = pd.read_csv(output_dir+"conv.csv")
    sub_steps = 1
    iters = df["iter"].values * sub_steps
    step = df["step"].values
    oobf = df["oobf"].values
    energy = df["energy"].values
    plastic = df["plastic"].values
    plastic = plastic / np.max(plastic)
    damage = df["damage"].values
    damage = damage / np.max(damage)
    ax.plot(iters,oobf,label="Residual")
    thresh_scale = 1e-2
    thresh_scale_damage = 1e-3
    ax.axhline(thresh_scale,c="green",ls="--")
    # ax.set_ylim(bottom=0,top=thresh_scale_damage*2)
    ax.set_yscale("log")
    # ax.set_yscale("log")
    ax_damage.scatter(iters,damage,label="Damage",c="red")
    ax_damage.plot(iters,plastic,label="Plastic",c="black")
    ax_damage.set_ylim(bottom=0)
    offset = 1
    for i in range(len(df)-1):
        if step[i] != step[i+1]:
            ##Transition found
            x = iters[i+1]
            ax.axvline(x,color="black")
            ax.text(x+offset,-0.30,'Step {}'.format(step[i+1]),rotation=90)
    lines, labels = ax.get_legend_handles_labels()
    lines2, labels2 = ax_damage.get_legend_handles_labels()
    ax_damage.legend(lines + lines2, labels + labels2, loc=0)
    plt.tight_layout()

def plot_de():
    df = pd.read_csv(output_dir+"timesteps.csv")
    ax = ax_de_residual
    ax_damage = ax_de_damage
    ax.clear()
    ax_damage.clear()
    ax.set_yscale("log")
    time = df["time"].values
    ax_damage.plot(time,df["damage"].values,label="Damage",c="red",marker="x")
    ax.plot(df["time"].values,df["energy"].values,label="Energy",c="orange")
    ax.plot(df["time"].values,df["oobf"].values,label="OOBF",c="green")
    colour_map = {"QUASI-STATIC":"none","DYNAMIC":"black","ACCELERATE":"green"}
    quasi_point = time[0] 
    quasi_type = df["step-type"].iloc[0]
    for i in range(1,len(df)):
        step_type = df["step-type"].iloc[i]
        if not quasi_type == step_type:
            plt.axvspan(quasi_point,time[i-1],alpha=0.25,color=colour_map[quasi_type])
            quasi_type = step_type
            quasi_point = time[i-1]
            plt.axvspan(quasi_point,time[i],alpha=0.25,color=colour_map[quasi_type])
    lines, labels = ax.get_legend_handles_labels()
    lines2, labels2 = ax_damage.get_legend_handles_labels()
    ax_damage.legend(lines+lines2, labels+labels2, loc=0)

plt.ion()
running = True
def on_close(event):
    global running
    running = False
fig.canvas.mpl_connect('close_event', on_close)
while(running):
    plot_conv()
    plot_de()
    plt.pause(1)
