#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Dec  8 14:40:47 2025

@author: plkn
"""

# Imports
import os
import glob

# Path to eprime logfiles
path_in = "/mnt/data_dump/emotiview/0_raw/"

# Iterate all txt files in folder (should be the logfiles)
for filepath in glob.glob(os.path.join(path_in, "*.txt")):
    
    # Open logfile
    with open(filepath, "r", encoding="utf-16") as f:
        content = f.read()
    
    #
    procedures = []
    in_block = False
    
    # Split to individual lines
    for line in content.splitlines():
        
        # Check if within Logframe block
        if "*** LogFrame Start ***" in line:
            in_block = True
            continue
        if "*** LogFrame End ***" in line:
            in_block = False
            continue
        
        # Check if Prcedures line
        if in_block and "Procedure: " in line:
            
            # Get procedure
            procedure = line.strip().split(" ")[1]
            
            # If bisbas scale
            if procedure == "bisBasProc":
                event = {"type": "bisbas"}
                
            
            
            procedures.append(procedure)
            
            
set_procedures = list(set(procedures))

