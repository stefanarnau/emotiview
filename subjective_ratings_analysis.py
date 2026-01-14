#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Jan 14 16:22:02 2026

@author: plkn
"""

# Imports
import os
import glob
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# Path to eprime logfiles
path_in = "/mnt/data_dump/emotiview/0_raw/"

all_movies = []

# Iterate all csv
for filepath in glob.glob(os.path.join(path_in, "*.csv")):

    # Read df
    df = pd.read_csv(filepath, sep=",")
    
    movie_types = []
    mov = {}

    # Iterate df
    for _, row in df.iterrows():
        if row["event_type"] == "movie_start":
            
            mov = {}
            mov["type"] = row["item"][:3]
            mov["subject_id"] = row["subject_id"]
            
        if row["event_type"] in {"ea11", "ea7", "SAM"}:
            label = row["event_type"] + "_" + row["item"]
            mov[label] = row["response_value"]
            
        if len(mov) == 22:
            all_movies.append(mov)
            mov = {}
            
# List of movies to df
df = pd.DataFrame(all_movies)
            
# Average within condition
df_avg = (
    df
    .groupby(["subject_id", "type"], as_index=False)
    .mean()
    )

# Make long format for plotting
dv_cols = df_avg.columns.difference(["subject", "type"])
df_long = df_avg.melt(
    id_vars=["subject_id", "type"],
    value_vars=dv_cols,
    var_name="dv",
    value_name="value"
)

g = sns.catplot(
    data=df_long,
    x="type",
    y="value",
    col="dv",
    kind="point",
    errorbar="sd",
    col_wrap=5,
    height=3,
    aspect=1,
    sharey=False
)

g.set_titles("{col_name}")
g.set_axis_labels("", "Value")
plt.tight_layout()
plt.show()