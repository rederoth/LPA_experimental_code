# Experimental design and analysis code for "Gaze Behavior Reveals Expectations of Potential Scene Changes"

Please refer to the manuscript *Gaze Behavior Reveals Expectations of Potential Scene Changes* (under review) or the [Anonymized OSF Project](https://osf.io/2skr3/?view_only=057f974b0703410293299ef7ca6b7531) for details about this project. 
The experimental code is based on Psychtoolbox-3 and is written in MATLAB. The parsing of the eye tracking data (recorded with an Eyelink 1000+) and the analysis code is written in Python. 

## Usage

### Experiment
Download the *Stimuli* data from the [OSF Storage](https://osf.io/2skr3/files/osfstorage?view_only=f72d2087fa074ed9ba902d385654136d) and place both the video and image files in the `Stimuli` folder (no subdirectories). It might be necessary to specify the full/absolute path to this folder in `runLPA.m`, line 32. The recorded eye-tracking data will be stored in the `EDF` folder, and the participant and trial information in the `Data` folder.

### Analysis
We used EyeLink Software to convert the EDF files to the ASC files uploaded to the [OSF Storage](https://osf.io/2skr3/files/osfstorage?view_only=f72d2087fa074ed9ba902d385654136d). The `parse_LPA_5s.py` script takes the raw data as input, parses the EyeLink messages, and generates writes the eye-tracking data of the first 5 seconds of stimulus presentation in the `LPA_5s_SUBJID_eye.csv.gz` and the corresponding trial information in the `LPA_5s_SUBJID_data.csv.gz` flies for all participants (SUBJIDs). The parsed data is then evaluated (ideally on a high-performance computing cluster since the NSS calculations and the tolerance radius to determine which object was foveated can lead to a high computational load) first with the `evaluate_metrics_psychsci_hpc.py` script, whose outputs are subsequently used by `evaluate_metrics_psychsci_nss_hpc.py`. The resulting `LPA_5s_SUBJID_eval_rad05_all_hpc.csv.gz` files are then used to analyze the effect and produce the figures reported in the manuscript in the `psysci_figures.ipynb` notebook. The object-based analysis of the fixations is partially performed in the `fix_obj_summary_psycsci.py` script, which also creates summary statistics used in `psysci_figures.ipynb` (also uploaded to OSF).

## More information

***Will be added after the double-blind review process.***
