#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Dec  8 14:40:47 2025

@author: plkn
"""

# Imports
import os
import glob
import numpy as np
import pandas as pd

# Path to eprime logfiles
path_in = "/mnt/data_dump/emotiview/0_raw/"

# Iterate all txt files in folder (should be the logfiles)
for filepath in glob.glob(os.path.join(path_in, "*.txt")):
    
    # Get subject id
    subject_id = filepath.split("/")[-1:][0][:-4]
    
    # Create event df
    df = pd.DataFrame()
    
    # Open logfile
    with open(filepath, "r", encoding="utf-16") as f:
        content = f.read()
    
    # Set in block
    in_block = False
    
    # Split to individual lines
    for line_idx, line in enumerate(content.splitlines()):
        
        # Get meta
        if "Subject" in line:
            subject_eprime_id = int(line.strip().split(": ")[1])
            continue
        if "Age" in line:
            age = int(line.strip().split(": ")[1])
            continue
        if "Sex" in line:
            sex = line.strip().split(": ")[1]
            continue
        
        # Check if within Logframe block
        if "*** LogFrame Start ***" in line:
            in_block = True
            continue
        
        # Get procedure name
        if in_block and "Procedure: " in line:
            procedure_name = line.strip().split(" ")[1]
            continue
                
        # Get onset time
        if in_block and ".OnsetTime: " in line:
            procedure_latency = int(line.strip().split(": ")[1])
            continue
        if in_block and ".FirstFrameTime: " in line:
            procedure_latency = int(line.strip().split(": ")[1])
            continue
        
        # Get trigger number
        if in_block and "Trigger: " in line:
            trigger_number = line.strip().split("Trigger: ")[1]
            continue
            
        # Get prodedure value
        if in_block and ".Value: " in line:
            if len(line.strip().split(": ")) > 1:
                response_value = int(line.strip().split(": ")[1])
            else:
                response_value = np.nan
            continue
            
        # Check if bisbas and get item
        if in_block and procedure_name == "bisBasProc":
            if "bis: " in line:
                event_item = line.strip().split("bis: ")[1]
                continue
            
        # Check if panas and get item
        if in_block and procedure_name == "panasProc":
            if "panas: " in line:
                event_item = line.strip().split("panas: ")[1]
                continue
            
        # Check if SAM and get item
        if in_block and procedure_name == "samProc":
            if "samBackgroundImg: " in line:
                event_item = line.strip().split("samBackgroundImg: ")[1].split(".")[0][3:]
                continue
            
        # Check if ea11 and get item
        if in_block and procedure_name == "ea11Proc":
            if "adjective: " in line:
                event_item = line.strip().split("adjective: ")[1].split(".")[0]
                continue
            
        # Check if be7 and get item
        if in_block and procedure_name == "be7Proc":
            if "emotion: " in line:
                event_item = line.strip().split("emotion: ")[1].split(".")[0]
                continue
        
        # Check if movie and get item
        if in_block and "movieFilename: " in line:
            event_item = line.strip().split("movieFilename: ")[1].split(".")[0]
            continue
        
        # If procedure ends
        if "*** LogFrame End ***" in line:
            
            # Create event
            event = {"subject_id": subject_id,
                     "subject_eprime_id": subject_eprime_id,
                     "age": age,
                     "sex": sex,
                     "event_type": procedure_name,
                     "trigger_number": trigger_number,
                     "event_latency": procedure_latency,
                     "response_value": response_value,
                     "item": event_item,
                     }
            
            # Append event
            df = pd.concat([df, pd.DataFrame([event])], ignore_index=True)
            
            # Reset vars
            in_block = False
            procedure_name = np.nan
            procedure_latency = np.nan
            response_value = np.nan
            event_item = np.nan
    
    # Rename event types
    df['event_type'] = df['event_type'].replace({
        'bisBasProc': 'bisbas',
        'panasProc': 'panas',
        'samProc': 'SAM',
        'ea11Proc': 'ea11',
        'be7Proc': 'ea7',
        'movieTrialProc': 'movie_start',
        'movieTrainingProc': 'movie_training',
    })
    
    # Sort by latency
    df = df.sort_values(by='event_latency')
    
    # Save df
    fn = "eprime_events_subject_" + subject_id + ".csv"
    df.to_csv(os.path.join(path_in, fn), index=False)

                
            


