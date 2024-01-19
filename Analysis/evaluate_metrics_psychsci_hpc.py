import os
import pandas as pd
import numpy as np
import glob
import argparse
import time
from skimage.transform import resize
from pymatreader import read_mat

# from remodnav.clf import EyegazeClassifier


def transform_x(
    input, video_min=192.0, video_max=1728.0, target_min=0.0, target_max=1920.0
):
    try:
        num = float(input)
    except ValueError:
        return np.NaN
    # check if x val exceeds boundaries of the video
    if (video_max <= num) or (num < video_min) or np.isnan(num):
        return np.NaN
    else:
        return int(
            (num - video_min + target_min)
            * target_max
            / (video_max - video_min + target_min)
        )


def transform_y(
    input, video_min=108.0, video_max=972.0, target_min=0.0, target_max=1080.0
):
    try:
        num = float(input)
    except ValueError:
        return np.NaN
    # check if val exceeds boundaries of the video
    if (video_max <= num) or (num < video_min) or np.isnan(num):
        return np.NaN
    else:
        return int(
            (num - video_min + target_min)
            * target_max
            / (video_max - video_min + target_min)
        )


def get_saliency_dg(path, scene):
    sal = np.exp(np.load(path + f"dg2e_{scene}_cb.npy"))
    sal = resize(sal, (1080, 1920), order=3)
    sal = (sal - np.mean(sal)) / np.std(sal)
    # sal_ncb = np.exp(np.load(path + f"dg2e_{scene}_nocb.npy"))
    # sal_ncb = resize(sal_ncb, (1080, 1920))
    # sal_ncb = (sal_ncb - np.mean(sal_ncb)) / np.std(sal_ncb)
    return sal  # , sal_ncb


def get_saliency_tb(path, scene):
    sal = read_mat(path + f"saltb_{scene}.mat")["bigMap"]
    assert sal.shape == (1080, 1920), "Saliency map has wrong shape."
    sal = (sal - np.mean(sal)) / np.std(sal)
    return sal


def create_expert_df(path):
    expert_list = glob.glob(f"{path}*.csv")
    df_pfa = pd.DataFrame()
    for expert_str in expert_list:
        expert_name = expert_str.split("/")[-1][:-12]
        print(expert_name, expert_str)
        df_temp = pd.read_csv(
            expert_str, header=None, names=["scene", "r0", "r1", "r2", "r3"]
        )
        df_temp["expert"] = expert_name
        df_pfa = pd.concat([df_pfa, df_temp], ignore_index=True)
    return df_pfa


def get_potential_for_action(df_pfa, scene):
    pfa_mask = np.zeros((1080, 1920))
    df_temp = df_pfa[df_pfa["scene"] == scene]
    for i in range(len(df_temp)):
        r = [
            int(df_temp.iloc[i][1]),
            int(df_temp.iloc[i][2]),
            int(df_temp.iloc[i][3]),
            int(df_temp.iloc[i][4]),
        ]
        pfa_mask[r[1] : r[1] + r[3], r[0] : r[0] + r[2]] += 1
    pfa_mask /= np.std(pfa_mask)
    pfa_mask -= np.mean(pfa_mask)
    return pfa_mask


def eval_arr(arr, x, y):
    if np.isnan([y, x]).any():
        return np.NaN
    else:
        return arr[int(y), int(x)]


def object_at_position(segmentationmap, xpos, ypos, radius=None):
    """
    Function that returns the currently gazed object with a tolerance (radius)
    around the gaze point. If the gaze point is on the background but there are
    objects within the radius, it is not considered to be background.

    :param segmentationmap: Object segmentation of the current frame
    :type segmentationmap: np.array
    :param xpos: Gaze position in x direction
    :type xpos: int
    :param ypos: Gaze position in y direction
    :type ypos: int
    :param radius: Tolerance radius, objects within that distance of the gaze point
        are considered to be foveated, defaults to None
    :type radius: float, optional
    :return: Name of the object(s) at the given position / within the radius
    :rtype: str
    """
    if np.isnan([xpos, ypos]).any():
        return ""
    (h, w) = segmentationmap.shape
    xpos = int(xpos)
    ypos = int(ypos)

    if radius == None:
        objid = segmentationmap[ypos, xpos] 
        if objid == 0:
            objname = "B"
        else:
            objname = str(objid)
        return objname
    # more interesting case: check in radius!
    center_objid = segmentationmap[ypos, xpos]
    if center_objid > 0:
        return str(center_objid)
    # check if all in rectangle is ground, then no need to draw a circle
    elif (
        np.sum(
            segmentationmap[
                max(0, int(ypos - radius)) : min(h - 1, int(ypos + radius)),
                max(0, int(xpos - radius)) : min(w - 1, int(xpos + radius)),
            ]
        )
        == 0
    ):
        return "B"
    # Do computationally more demanding check for a radius
    # store all objects other than `Ground` that lie within the radius
    else:
        Y, X = np.ogrid[:h, :w]
        dist_from_center = np.sqrt((X - xpos) ** 2 + (Y - ypos) ** 2)
        mask = dist_from_center <= radius
        objects = np.unique(mask * segmentationmap)
        if len(objects) == 1 and 0 in objects:
            return "B"
        else:
            return ", ".join([f"{obj}" for obj in objects if (obj > 0)])


EM_LABELS = {
    "FIXA": "FOV",
    "PURS": "FOV",
    "SACC": "SAC",
    "ISAC": "SAC",
    "HPSO": "PSO",
    "IHPS": "PSO",
    "LPSO": "PSO",
    "ILPS": "PSO",
    "PSO": "PSO",
}


def main():
    PARSED_PATH = "LPA_5s_parsed_data/"
    SAL_PATH = "Saliency/"
    OBJ_PATH = "Segmentation/"
    RATING_PATH = "ExpertRatings/"
    STORE_PATH = "LPA_5s_eval_psycsci/"
    # if not os.path.exists(STORE_PATH):
    #     os.makedirs(STORE_PATH)

    parser = argparse.ArgumentParser()
    parser.add_argument("--subject_id", type=str)
    args = parser.parse_args()
    subject_id = args.subject_id
    print("Subject ", subject_id)

    DF_PFA = create_expert_df(RATING_PATH)
    px2deg = 47.7 / 1920  # factor 0.8 only after transform!!!
    px2deg_trans = (47.7 * 0.8) / 1920
    # after the transformation, there should be more pixels in 1 DVA!
    # since the stimulus is effectively made more high resolution
    # ==> 0.8 should be in the numerator! 100px * px2deg = 1dva
    halfdva = 0.5 / px2deg_trans

    # for subject_id in subj_ids:
    # print(f"Subject {subject_id}")
    df_data = pd.read_csv(
        f"{PARSED_PATH}LPA_5s_{subject_id}_data.csv.gz", compression="gzip"
    )
    df_eye = pd.read_csv(
        f"{PARSED_PATH}LPA_5s_{subject_id}_eye.csv.gz", compression="gzip"
    )
    dom = df_data.dom_eye.iloc[0]

    df_eval = pd.DataFrame()

    for i in range(len(df_data)):
        b = df_data.block.iloc[i]
        tb = df_data.trial.iloc[i]
        scene = df_data.scene.iloc[i]
        print(f"Subject {subject_id}, Block {b}, Trial {tb}, Scene {scene}")
        df_sgl = df_eye[(df_eye["block"] == b) & (df_eye["trial_in_block"] == tb)]
        df_sgl = df_sgl.rename(columns={f"x{dom}": "x", f"y{dom}": "y"})
        recarr_sgl = df_sgl[["x", "y"]].to_records()

        clf = EyegazeClassifier(
            px2deg=px2deg,
            sampling_rate=1000,
            pursuit_velthresh=1e6,
            noise_factor=3.0,
        )
        try:
            p = clf.preproc(recarr_sgl, savgol_length=0.005, dilate_nan=0.025)
        except np.linalg.LinAlgError:
            print("LinAlgError!", subject_id, b, tb, scene)
            p = clf.preproc(recarr_sgl, savgol_length=0, dilate_nan=0.025)
        detectedEvents = clf(p)

        events = np.empty(len(df_sgl), dtype=object)
        for ev in detectedEvents:
            events[
                int(ev["start_time"] * 1000) : int(ev["end_time"] * 1000)
            ] = EM_LABELS[ev["label"]]

        df = pd.DataFrame()
        df["t"] = df_sgl["t"]
        df["x"] = df_sgl["x"].apply(transform_x)  # .astype('Int64')
        df["y"] = df_sgl["y"].apply(transform_y)  # .astype('Int64')
        df["em_rv"] = events
        # filling not done in old dfs!
        df["em_rv"].fillna("-", inplace=True)  # for storing in csv
        sal_dg = get_saliency_dg(SAL_PATH, scene)
        # instead of no_cb use sal_tb! (manually changed in old dfs!)
        sal_tb = get_saliency_tb(SAL_PATH, scene)
        pfa = get_potential_for_action(DF_PFA, scene)
        obj_mask = np.load(OBJ_PATH + scene + ".npy")

        df["sal"] = df.apply(lambda row: eval_arr(sal_dg, row["x"], row["y"]), axis=1)
        df["sal_tb"] = df.apply(
            lambda row: eval_arr(sal_tb, row["x"], row["y"]), axis=1
        )
        df["pfa"] = df.apply(lambda row: eval_arr(pfa, row["x"], row["y"]), axis=1)
        df["obj"] = df.apply(
            # halfdva gives tolerance ==> heavy computation!
            lambda row: object_at_position(obj_mask, row["x"], row["y"], halfdva),
            axis=1,
        )
        df.insert(0, "subj_id", subject_id)
        df.insert(1, "block", b)
        df.insert(2, "trial_in_block", tb)
        df.insert(3, "scene", scene)
        df.insert(4, "video", df_data["video"].iloc[i])
        df.insert(5, "seen", np.sum(df_data.scene.iloc[:i] == scene))
        df.insert(6, "animate", df_data["animate"].iloc[i])

        df_eval = pd.concat([df_eval, df], ignore_index=True)

    df_eval.to_csv(
        f"{STORE_PATH}LPA_5s_{subject_id}_eval_rad05_no_nss_hpc.csv.gz",
        compression="gzip",
        index=False,
    )


if __name__ == "__main__":
    main()
