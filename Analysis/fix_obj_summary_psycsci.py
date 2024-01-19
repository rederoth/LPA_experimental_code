import os
import pandas as pd
import numpy as np
import glob
from collections import Counter

import evaluate_metrics_psychsci_hpc as em


def compute_fov_props(group):
    # Get the start and end times, mean coordinates, and object with the most occurrences
    if group["em_rv"].iloc[0] == "FOV":
        scene = group["scene"].iloc[0]
        video = group["video"].iloc[0]
        subj_id = str(group["subj_id"].iloc[0])
        b = group["block"].iloc[0]
        trial = group["trial_in_block"].iloc[0]
        t_start, t_end = group["t"].iloc[[0, -1]]
        x_mean, y_mean = group[["x", "y"]].mean()
        obj = Counter(", ".join(group["obj"]).split(", ")).most_common(1)[0][0]
        if obj in ["B", "nan", "-"]:
            obj_name = "B"
            # obj_size = np.NaN
            # obj_pfa = np.NaN
            # obj_sal = np.NaN
            # obj_sal_tb = np.NaN
        else:
            obj_name = scene + "_" + obj
            # obj_size = d_obj_size[scene][obj]
            # obj_pfa = d_obj_pfa[scene][obj]
            # obj_sal = d_obj_sal_dg[scene][obj]
            # obj_sal_tb = d_obj_sal_tb[scene][obj]

        return pd.Series(
            {
                "subj_id": subj_id,
                "block": b,
                "trial_in_block": trial,
                "trial_id": f"{subj_id}_{b:02d}_{trial:02d}",
                "scene": scene,
                "video": video,
                "t_start": t_start,
                "t_end": t_end,
                "fd": t_end - t_start,
                "x": x_mean,
                "y": y_mean,
                "obj": obj_name,
                # "obj_size": obj_size,
                # "obj_pfa": obj_pfa,
                # "obj_sal": obj_sal,
                # "obj_sal_tb": obj_sal_tb,
            }
        )


def get_fov_cats(group):
    fov_cats = []
    for i in range(len(group)):
        obj = group["obj"].iloc[i]
        if obj in ["B", "nan"]:
            fov_cats.append("B")
        elif (i > 0) and (group["obj"].iloc[i - 1] == obj):
            fov_cats.append("I")
        else:
            prev_obj = group["obj"].iloc[:i]
            if obj not in prev_obj.values:
                fov_cats.append("D")
            else:
                fov_cats.append("R")
    return fov_cats


def main():
    EVAL_PATH = "LPA_5s_eval_psycsci/"
    SAL_PATH = "/home/nico/project_code/LPA_study/Saliency/"
    OBJ_PATH = "/home/nico/project_code/LPA_study/Segmentation/"
    RATING_PATH = "/home/nico/project_code/LPA_study/ExpertRatings/"

    px2deg = (0.8 * 47.7) / 1920

    s_ids = [f[7:9] for f in os.listdir("LPA_5s_eval_psycsci/") if f.endswith(".csv")]
    s_ids = sorted(list(np.unique(s_ids)))    
    # if not yet done, combine NSS calculations with other metrics
    for s_id in s_ids:
        if not os.path.exists(f"{EVAL_PATH}LPA_5s_{s_id}_eval_rad05_all_hpc.csv.gz"):
            print(f"Combining NSS files for subject {s_id}...")
            df = pd.read_csv(f"{EVAL_PATH}LPA_5s_{s_id}_eval_rad05_no_nss_hpc.csv.gz", compression="gzip")
            for nss_size in ["nss1dva", "nss1.5dva", "nss2dva"]:
                df_nss = pd.read_csv(f"{EVAL_PATH}LPA_5s_{s_id}_eval_all_{nss_size}.csv.gz", compression="gzip")
                df[nss_size] = df_nss["nss"]
            df = df[df["t"] <= 5000]
            # save the combined file
            df.to_csv(f"{EVAL_PATH}LPA_5s_{s_id}_eval_rad05_all_hpc.csv.gz", compression="gzip", index=False)
            print(f"stored combined NSS file: {EVAL_PATH}LPA_5s_{s_id}_eval_rad05_all_hpc.csv.gz")
            
    print(" Calc object based dictionaries...")
    d_obj = {}
    # d_obj_size = {}
    # d_obj_pfa = {}
    # d_obj_sal_dg = {}
    # d_obj_sal_tb = {}
    scenes = [f[:-4] for f in sorted(os.listdir(OBJ_PATH))]
    DF_PFA = em.create_expert_df(RATING_PATH)
    for scene in scenes:
        s_obj_ids = []
        s_obj_pfa = []
        s_obj_sal_dg = []
        s_obj_sal_tb = []
        obj_mask = np.load(OBJ_PATH + scene + ".npy")
        sal_dg = em.get_saliency_dg(SAL_PATH, scene)
        sal_tb = em.get_saliency_tb(SAL_PATH, scene)
        pfa = em.get_potential_for_action(DF_PFA, scene)
        for obj in np.unique(obj_mask)[1:]:
            mask = obj_mask == obj
            obj = str(obj)
            scene_obj_id = scene + "_" + obj
            nmask = np.sum(mask)
            d_obj[scene_obj_id] = {}
            d_obj[scene_obj_id]["size"] = nmask
            d_obj[scene_obj_id]["pfa"] = np.sum(mask * pfa) / nmask
            d_obj[scene_obj_id]["sal_dg"] = np.sum(mask * sal_dg) / nmask
            d_obj[scene_obj_id]["sal_tb"] = np.sum(mask * sal_tb) / nmask
            # rest is to get the normalized values
            s_obj_ids.append(scene_obj_id)
            s_obj_pfa.append(d_obj[scene_obj_id]["pfa"])
            s_obj_sal_dg.append(d_obj[scene_obj_id]["sal_dg"])
            s_obj_sal_tb.append(d_obj[scene_obj_id]["sal_tb"])

        s_obj_pfa = np.array(s_obj_pfa)
        s_obj_sal_dg = np.array(s_obj_sal_dg)
        s_obj_sal_tb = np.array(s_obj_sal_tb)
        if len(s_obj_pfa) > 1:
            s_obj_pfa = s_obj_pfa - np.min(s_obj_pfa)
            s_obj_sal_dg = s_obj_sal_dg - np.min(s_obj_sal_dg)
            s_obj_sal_tb = s_obj_sal_tb - np.min(s_obj_sal_tb)
        s_obj_pfa = s_obj_pfa / np.max(s_obj_pfa)
        s_obj_sal_dg = s_obj_sal_dg / np.max(s_obj_sal_dg)
        s_obj_sal_tb = s_obj_sal_tb / np.max(s_obj_sal_tb)
        for i, scene_obj_id in enumerate(s_obj_ids):
            d_obj[scene_obj_id]["n_pfa"] = s_obj_pfa[i]
            d_obj[scene_obj_id]["n_sal_dg"] = s_obj_sal_dg[i]
            d_obj[scene_obj_id]["n_sal_tb"] = s_obj_sal_tb[i]

    df_obj = pd.DataFrame.from_dict(d_obj, orient="index")
    df_obj.index.name = "scene_obj"
    df_obj.to_csv(f"df_obj_props_psycsci.csv.gz", compression="gzip")

    ## now, calculate the FOV properties

    eval_files = sorted(
        [f for f in os.listdir(EVAL_PATH) if "_eval_rad05_all_hpc.csv.gz" in f]
    )
    subj_ids = [f[7:9] for f in eval_files]

    df_all = pd.DataFrame()

    for subject_id in subj_ids:
        print(f"Subject {subject_id}")
        df = pd.read_csv(
            f"{EVAL_PATH}LPA_5s_{subject_id}_eval_rad05_all_hpc.csv.gz",
            compression="gzip",
        )
        df = df[df.t < 5000]
        df["obj"] = df["obj"].astype(str)
        df_fovs = (
            df.groupby(
                [
                    "block",
                    "trial_in_block",
                    (df["em_rv"] != df["em_rv"].shift()).cumsum(),
                ]
            )
            .apply(compute_fov_props) # lambda group: compute_fov_props(group))
            .reset_index(drop=True)
        )
        df_fovs.dropna(subset=["x", "y"], inplace=True)
        df_fovs = df_fovs.astype(
            {
                "block": int,
                "trial_in_block": int,
                "video": int,
                "t_start": int,
                "t_end": int,
                "fd": int,
                "x": int,
                "y": int,
            }
        )
        next_x = df_fovs.groupby(["block", "trial_in_block"])["x"].shift(-1)
        next_y = df_fovs.groupby(["block", "trial_in_block"])["y"].shift(-1)
        df_fovs["amp"] = px2deg * np.sqrt(
            (df_fovs["x"] - next_x) ** 2 + (df_fovs["y"] - next_y) ** 2
        )
        df_fovs["fov_cat"] = (
            df_fovs.groupby(["block", "trial_in_block"])
            .apply(get_fov_cats)
            .explode()
            .tolist()
        )
        df_all = pd.concat([df_all, df_fovs])

    df_all.to_csv(f"df_all_fovs_psycsci.csv.gz", compression="gzip", index=False)

    ## lastly, calculate the #fix and dwell time per object per subject
    d_obj_nfov_diff = {}
    d_obj_dt_diff = {}
    
    df_obj = pd.read_csv(f"df_obj_props_psycsci.csv.gz", compression="gzip")
    for scene_obj in df_obj.scene_obj: 
        d_obj_nfov_diff[scene_obj] = {}
        d_obj_dt_diff[scene_obj] = {}
        
        df_fov_obj = df_all[df_all.obj == scene_obj]
        df_obj_img = df_fov_obj[df_fov_obj.video == 0]
        df_obj_vid = df_fov_obj[df_fov_obj.video == 1]

        for subj_id in df_all.subj_id.unique():
            s_id = str(subj_id)
            d_obj_nfov_diff[scene_obj][s_id] = {}
            d_obj_dt_diff[scene_obj][s_id] = {}
            df_o_i_subj = df_obj_img[df_obj_img.subj_id == subj_id]
            df_o_v_subj = df_obj_vid[df_obj_vid.subj_id == subj_id]
            d_obj_nfov_diff[scene_obj][s_id]["all"] = len(df_o_v_subj) - len(df_o_i_subj)
            d_obj_dt_diff[scene_obj][s_id]["all"] = df_o_v_subj.fd.sum() - df_o_i_subj.fd.sum()
            for fov_cat in ["D", "I", "R"]:
                df_o_i_subj_fov = df_o_i_subj[df_o_i_subj.fov_cat == fov_cat]
                df_o_v_subj_fov = df_o_v_subj[df_o_v_subj.fov_cat == fov_cat]
                d_obj_nfov_diff[scene_obj][s_id][fov_cat] = len(df_o_v_subj_fov) - len(df_o_i_subj_fov)
                d_obj_dt_diff[scene_obj][s_id][fov_cat] = df_o_v_subj_fov.fd.sum() - df_o_i_subj_fov.fd.sum()
            
    df_obj_nfov = pd.DataFrame.from_dict({(i,j): d_obj_nfov_diff[i][j] 
                            for i in d_obj_nfov_diff.keys() 
                            for j in d_obj_nfov_diff[i].keys()},
                        orient='index')
    df_obj_nfov.index = pd.MultiIndex.from_tuples(df_obj_nfov.index)
    df_obj_nfov.index.names = ['scene_obj', 'subj_id']
    df_obj_nfov.to_csv('df_obj_nfov_diff_psycsci.csv.gz', compression='gzip')

    df_obj_dt = pd.DataFrame.from_dict({(i,j): d_obj_dt_diff[i][j]
                                for i in d_obj_dt_diff.keys() 
                                for j in d_obj_dt_diff[i].keys()},
                            orient='index')
    df_obj_dt.index = pd.MultiIndex.from_tuples(df_obj_dt.index)
    df_obj_dt.index.names = ['scene_obj', 'subj_id']
    df_obj_dt.to_csv('df_obj_dt_diff_psycsci.csv.gz', compression='gzip')


if __name__ == "__main__":
    main()
