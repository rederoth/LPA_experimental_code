import os
import pandas as pd
import numpy as np
import time
import argparse


def gauss2d(shape, sigma):
    x = np.arange(shape[1])
    y = np.arange(shape[0])
    xx, yy = np.meshgrid(x, y, indexing="xy")
    G = np.exp(
        -0.5 * ((xx - shape[1] // 2) ** 2 + (yy - shape[0] // 2) ** 2) / sigma**2
    )
    return G


def shift_elements_to(arr, x, y):
    y0 = y - arr.shape[0] // 2
    x0 = x - arr.shape[1] // 2
    result = np.zeros_like(arr)
    if y0 > 0:
        result[y0:, :] = arr[:-y0, :]
    elif y0 < 0:
        result[:y0, :] = arr[-y0:, :]
    else:
        result[:, :] = arr[:, :]
    if x0 > 0:
        result[:, x0:] = result[:, :-x0]
        result[:, :x0] = 0
    elif x0 < 0:
        result[:, :x0] = result[:, -x0:]
        result[:, x0:] = 0
    else:
        result[:, :] = result[:, :]
    return result


def calc_nss(KERNEL, df_rest, scene, vid, t, x, y, em):
    if np.isnan([y, x]).any() or (em != "FOV") or (t > 5000):
        return np.NaN
    else:
        df = df_rest.loc[(scene, vid, t)]
        X_rest = np.array(df["x"], dtype=int)
        Y_rest = np.array(df["y"], dtype=int)
        temp = np.zeros_like(KERNEL)
        for i in range(len(df)):
            temp += shift_elements_to(KERNEL, X_rest[i], Y_rest[i])
        temp = (temp - np.mean(temp)) / np.std(temp)
        return temp[int(y), int(x)]


def main():
    t_start = time.time()

    EVAL_PATH = "/home/users/n/nicolas-roth/LPA/LPA_5s_eval_psycsci/"
    px2deg = (47.7 * 0.8) / (1920)  # 0.8 is the scaling factor, vals are transformed!
    # 0.8 should actually be in the numerator!! (corrected now)
    # --> effectively this means NSS was calculated on a 1.28 instead of 2dva.
    # kernel = gauss2d((1080, 1920), 2 * 0.8**2 / px2deg) # this effectively ran previously
    kernel = gauss2d((1080, 1920), 2 / px2deg)  # this is correct now!

    eval_files = sorted(os.listdir(EVAL_PATH))  #
    subj_ids = [f[7:9] for f in eval_files]

    parser = argparse.ArgumentParser()
    parser.add_argument("--subject_id", type=str)
    args = parser.parse_args()
    subject_id = args.subject_id
    print("Subject ", subject_id)

    df_rest = pd.DataFrame()
    for s in subj_ids:
        if s == subject_id:
            df_sub = pd.read_csv(
                f"{EVAL_PATH}LPA_5s_{s}_eval_rad05_no_nss_hpc.csv.gz", compression="gzip"
            )
        else:
            df_rest = pd.concat(
                [
                    df_rest,
                    pd.read_csv(
                        f"{EVAL_PATH}LPA_5s_{s}_eval_rad05_no_nss_hpc.csv.gz",
                        compression="gzip",
                        usecols=["scene", "video", "x", "y", "t", "em_rv"],
                    ),
                ],
            )

    df_sub["nss"] = np.nan

    df_rest = df_rest[df_rest["em_rv"] == "FOV"]
    df_rest.drop(columns=["em_rv"], inplace=True)
    df_rest = df_rest[df_rest.isna().any(axis=1) == False]
    df_rest = df_rest.set_index(["scene", "video", "t"]).sort_index()

    t_setup = time.time()
    print(f"{subject_id} time for setting it up: ", t_setup - t_start)

    df_sub["nss"] = df_sub.apply(
        lambda row: calc_nss(
            kernel,
            df_rest,  # .loc[(row["scene"], row["video"], row["t"])],
            row["scene"],
            row["video"],
            row["t"],
            row["x"],
            row["y"],
            row["em_rv"],
        ),
        axis=1,
    )

    df_sub["em_rv"].fillna("-", inplace=True)  # for storing in csv

    df_sub.to_csv(
        f"{EVAL_PATH}LPA_5s_{subject_id}_eval_all.csv.gz",
        compression="gzip",
        index=False,
    )
    print(subject_id, "stored! time: ", time.time() - t_setup)


if __name__ == "__main__":
    main()
