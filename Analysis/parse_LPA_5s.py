import os
import pandas as pd
from pymatreader import read_mat
import csv
import gzip
import numpy as np


def transform_x(input, video_min=192, video_max=1728, target_min=0, target_max=1920):
    try:
        num = float(input)
    except ValueError:
        return np.NaN
    num = float(input)
    # check if x val exceeds boundaries of the video
    if (video_max <= num) or (num < video_min):
        return np.NaN
    else:
        return (
            (num - video_min + target_min)
            * target_max
            / (video_max - video_min + target_min)
        )


def transform_y(input, video_min=108, video_max=972, target_min=0, target_max=1080):
    try:
        num = float(input)
    except ValueError:
        return np.NaN
    num = float(input)
    # check if val exceeds boundaries of the video
    if (video_max <= num) or (num < video_min):
        return np.NaN
    else:
        return (
            (num - video_min + target_min)
            * target_max
            / (video_max - video_min + target_min)
        )


def float_or_nan(input):
    try:
        num = float(input)
    except ValueError:
        return np.NaN
    return num


d_animate = {
    "axolotl": 1,
    "ballBalance": 0,
    "bed": 0,
    "bench": 1,
    "bigAnimalBackground": 1,
    "bikeUnlocking": 1,
    "billboard": 0,
    "bird": 1,
    "birdFalling": 0,
    "blueBoiler": 0,
    "bottleString": 0,
    "candle": 0,
    "carStart": 0,
    "catcafe": 1,
    "chessBoard": 1,
    "chimpanzee": 1,
    "clock": 0,
    "coffeeOnSofa": 1,
    "construction": 1,
    "conversation": 1,
    "crow": 1,
    "crowBall": 1,
    "dino": 0,
    "disinfectant": 0,
    "elevatorEmpty": 0,
    "elevatorWrongSide": 1,
    "espresso": 0,
    "fingerTapping": 1,
    "fish": 1,
    "fly": 1,
    "giraffe": 1,
    "gondolaUp": 0,
    "heron": 1,
    "kettle": 0,
    "lake": 1,
    "laundry": 0,
    "lizard": 1,
    "mail": 1,
    "mokaPot": 0,
    "monitorLizard": 1,
    "monkey2": 1,
    "openDoorInside": 0,
    "openDoorOutside": 1,
    "pedestrian": 1,
    "penDrawing": 0,
    "phone": 0,
    "plank": 1,
    "receipt": 0,
    "reindeers": 1,
    "rippingPaper": 0,
    "robot": 0,
    "robot2": 1,
    "sealion": 0,
    "selfie": 1,
    "shoebill": 1,
    "shoot": 1,
    "skiLift": 0,
    "snip": 0,
    "sparkling2": 0,
    "stapler": 0,
    "statues": 1,
    "teabagOut": 0,
    "throw": 1,
    "toaster": 0,
    "toytrain": 0,
    "toytrainHouses": 0,
    "trafficLight": 0,
    "trafficLight2": 0,
    "trash": 1,
    "trinkvogel2": 0,
    "ventilator": 0,
    "waterHose": 0,
    "waterbottle": 0,
    "watercooler": 0,
    "watering": 1,
    "whiteBoard": 0,
    "work": 1,
    "work2": 1,
    "yoga": 1,
    "youtube": 1,
}


DATA_PATH = "/home/nico/project_data/LPA/data/raw_data/"
STORE_PATH = "/home/nico/project_data/LPA/data/LPA_5s_parsed_data/"
asc_files = sorted([f for f in os.listdir(DATA_PATH) if ".asc" in f])
mat_files = sorted(
    [f for f in os.listdir(DATA_PATH) if (".mat" in f) and ("trialinfo" not in f)]
)
subj_ids = [f[-8:-6] for f in asc_files]
assert len(asc_files) == len(mat_files), "Some files are missing!"

for subject_id in sorted(list(set(subj_ids))):
    print(f"======== {subject_id} ========")
    incomplete_flag = ""
    #### MAT dataframe
    # mulitple paths if subject has multiple files
    mat_subj_files = [os.path.join(DATA_PATH, f) for f in mat_files if subject_id in f]
    asc_subj_files = [os.path.join(DATA_PATH, f) for f in asc_files if subject_id in f]
    start_blocks = [int(f.split("_")[1][0]) for f in mat_files if subject_id in f]

    df_mat = pd.DataFrame()
    for m_idx, mat_path in enumerate(mat_subj_files):
        data = read_mat(mat_path)
        dom_eye = data["setting"]["eye_used"]
        if dom_eye == 0:
            dom_eye = "l"
        elif dom_eye == 1:
            dom_eye = "r"
        else:
            raise Exception("Dominant eye has to be 0 or 1!")
        if isinstance(data["data"]["b"]["trial"], list):
            data = data["data"]["b"]["trial"]
        else:
            data = [data["data"]["b"]["trial"]]

        # stored block-wise, here read all trials of one block in as one dataframe
        for b in range(len(data)):
            try:
                df = pd.DataFrame(data[b])
            except:
                continue
            # only keep trials where fixation requirement was passed
            df = df[df["fixReq"] == 0]
            df["fix_control_x"] = [
                transform_x(df["fix_pos"].iloc[i][0]) for i in range(len(df))
            ]
            df["fix_control_y"] = [
                transform_y(df["fix_pos"].iloc[i][1]) for i in range(len(df))
            ]
            # check if response (1 or 2) is correct
            df["ans_cor"] = (df["correct"] == df["ans1"]) == df["resp"] % 2
            # set to nan if no question was asked
            df.loc[df["rt"].isna(), "ans_cor"] = np.nan
            df["block"] = b + start_blocks[m_idx]
            # check if display time was correct
            if df["video"].iloc[0]:
                assert (
                    np.round(
                        df.t_flip_last - df.t_flip_image,
                        1,
                    )
                    == 10.0
                ).all(), "Display time is not 10s!"
            else:
                assert (
                    np.round(
                        df.t_flip_secondimend - df.t_flip_image,
                        2,
                    )
                    == 10.00
                ).all(), "Display time is not 10s!"
            dropcols = [
                "ask",
                "question",
                "correct",
                "ans1",
                "ans2",
                "nr_iteration",
                "moviename",
                "video_file_exists",
                "moviedata",
                "all_tex",
                "frame_dur",
                "imagename",
                "image_file_exists",
                "video_scale_factor",
                "v_width",
                "v_height",
                "video_dest_rect",
                "fix_pos",
                "n_frames",
                "n_flips",
                "do_escape",
                "fixReq",
                "fixaOn",
                "fixStart",
                "fixBrokenCntr",
                "fixBrokenTime",
                "fixEnd",
                "x",
                "y",
                "t",
                "t_eye",
                "t_flip_first",
                "t_all_frames",
                "t_flip_last",
                "t_flip_image",
                "t_flip_first_video",
                "dropped",
                "calib_result",
                "t_question_on",
                "resp",
                "t_resp",
                "t_flip_secondim",
                "t_flip_secondimend",
                "rt_lastflip",
            ]
            for col_name in dropcols:
                df.drop(col_name, axis=1, inplace=True)
            if m_idx > 0:
                # check for duplicates in df_mat
                mask = (
                    df_mat[["block", "fileName"]]
                    .isin(df[["block", "fileName"]].to_dict("list"))
                    .all(axis=1)
                )
                if mask.any():
                    print(mask)
                    # subset df to exclude duplicates
                    df = df[
                        ~df[["block", "fileName"]]
                        .isin(df_mat.loc[mask, ["block", "fileName"]].to_dict("list"))
                        .all(axis=1)
                    ]

            df_mat = pd.concat([df_mat, df], ignore_index=True)
    df_mat.insert(0, "subj_id", subject_id)
    df_mat.insert(1, "dom_eye", dom_eye)
    # add scene name as column and if that scene is animate or not
    scenename = [
        df_mat.fileName[i].split("_")[0].split(".")[0] for i in range(len(df_mat))
    ]
    df_mat["scene"] = scenename
    df_mat["animate"] = [d_animate[scene] for scene in df_mat.scene]
    if len(df_mat) != 160:
        print(f"WARNING: Not 160 trials in mat dataframe for subject {subject_id}!")
        incomplete_flag = "_INCOMPLETE"
    # assert (subject_id == "21") or (len(df_mat) == 160), "Not 160 trials in mat dataframe!"
    df_mat.to_csv(
        f"{STORE_PATH}LPA_5s_{subject_id}_data{incomplete_flag}.csv.gz",
        compression="gzip",
        index=False,
    )

    ### ASC dataframe
    csv_filename = f"{STORE_PATH}LPA_5s_{subject_id}_eye{incomplete_flag}.csv.gz"
    valid_counter = 0
    for a_idx, asc_path in enumerate(asc_subj_files):
        assert asc_path[-8:-6] == subject_id, "Subject ID not as in file name"
        with open(asc_path) as asc:
            content = asc.readlines()
            trial_starts = [
                [i, line] for i, line in enumerate(content) if ("TRIAL_Start" in line)
            ]
            # depening on starting block change mode
            starting_block = int(asc_path[-5:-4])
            if starting_block == 1:
                mode = "wt"
            else:
                mode = "at"
            with gzip.open(csv_filename, mode=mode, newline="") as csv_file:
                writer = csv.writer(csv_file)
                if mode == "wt":
                    writer.writerow(
                        [
                            "subject_id",
                            "block",
                            "trial_in_block",
                            "trialCntr",
                            "filename",
                            "t",
                            "xl",
                            "yl",
                            "pl",
                            "xr",
                            "yr",
                            "pr",
                        ]
                    )
                for t, trial_line in enumerate(trial_starts):
                    [trial_lidx, trial_message] = trial_line
                    if t + 1 < len(trial_starts):
                        [next_trial_lidx, _] = trial_starts[t + 1]
                    else:
                        next_trial_lidx = -1
                    assert (
                        int(trial_message.split(" ")[-1]) == t + 1
                    ), "Trial index is not trial number"
                    trialCntr = t + 1
                    if "TRIAL_in_BLOCK" in content[trial_lidx - 1]:
                        current_trial_in_block = int(
                            content[trial_lidx - 1].split(" ")[-1]
                        )
                        idx_shift = 0
                    elif "TRIAL_in_BLOCK" in content[trial_lidx - 2]:
                        current_trial_in_block = int(
                            content[trial_lidx - 2].split(" ")[-1]
                        )
                        idx_shift = 1
                    else:
                        raise Exception("TRIAL_in_BLOCK is not above trial start!")
                    if "BLOCK" in content[trial_lidx - 2 - idx_shift]:
                        current_block = int(
                            content[trial_lidx - 2 - idx_shift].split(" ")[-1]
                        )
                    elif "BLOCK" in content[trial_lidx - 3 - idx_shift]:
                        current_block = int(
                            content[trial_lidx - 3 - idx_shift].split(" ")[-1]
                        )
                    else:
                        raise Exception("BLOCK is not above trial start!")

                    block = starting_block - 1 + current_block
                    trial_in_block = current_trial_in_block

                    if valid_counter >= len(df_mat):
                        # should not be necessary, only in incompltete data...
                        print(f"skip sub {subject_id} trial {t+1} in block {block}")
                        continue
                    # what is the desired block & trial given df_mat?
                    m_block = df_mat.iloc[valid_counter]["block"]
                    m_trialCntr = df_mat.iloc[valid_counter]["trialCntr"]
                    m_trial_in_block = df_mat.iloc[valid_counter]["trial"]
                    m_filename = df_mat.iloc[valid_counter]["fileName"]
                    if (
                        (block == m_block)
                        & (trialCntr == m_trialCntr)
                        & (current_trial_in_block == m_trial_in_block)
                    ):
                        valid_counter += 1
                    else:
                        print(f"skip sub {subject_id} trial {t+1} in block {block}")
                        continue

                    # only consider data between the boundaries of the current trial
                    trial_data = content[trial_lidx:next_trial_lidx]
                    # filter for all events that correspond to the first image being flipped
                    image_events = [
                        [i, line]
                        for i, line in enumerate(trial_data)
                        if ("EVENT_image" in line)
                    ]
                    if 3 <= len(image_events) <= 4:
                        image_data = trial_data[image_events[0][0] : image_events[2][0]]
                        valid_trial_data = [
                            line.split("\t")[:-1]
                            for line in image_data
                            if line.split("\t")[0].isdigit()
                        ]

                        starttime = int(
                            valid_trial_data[0][0]
                        )  # set starting time to 0!
                        # parse the data and write to csv
                        for row in valid_trial_data:
                            t = int(row[0]) - starttime
                            xl = float_or_nan(row[1])
                            yl = float_or_nan(row[2])
                            pl = float_or_nan(row[3])
                            xr = float_or_nan(row[4])
                            yr = float_or_nan(row[5])
                            pr = float_or_nan(row[6])
                            # xl = transform_x(row[1])
                            # yl = transform_y(row[2])
                            # pl = float_or_nan(row[3])
                            # xr = transform_x(row[4])
                            # yr = transform_y(row[5])
                            # pr = float_or_nan(row[6])

                            writer.writerow(
                                [
                                    subject_id,
                                    block,
                                    trial_in_block,
                                    trialCntr,
                                    m_filename,
                                    t,
                                    xl,
                                    yl,
                                    pl,
                                    xr,
                                    yr,
                                    pr,
                                ]
                            )
    if valid_counter != 160:
        print(f"WARNING: Not 160 trials in asc dataframe for subject {subject_id}!")
    # assert (subject_id == "21") or (valid_counter) == 160), "Not 160 trials in mat dataframe!"
