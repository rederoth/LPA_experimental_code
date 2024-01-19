import os
import glob
import pandas as pd 
import numpy as np
from scipy import ndimage
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator

def plot_img_vs_vid(d_res, measure, ax, subj_ids=None, img_color="xkcd:blue", vid_color="xkcd:red", xlabel="Time (ms)", ylabel="Potential for change (a.u.)"):
    if subj_ids is not None:
        for i in range(len(subj_ids)):
            ax.plot(d_res[measure]["img"].iloc[i], label="Image", color=img_color, lw=0.1)
            ax.plot(d_res[measure]["vid"].iloc[i], label="Video", color=vid_color, lw=0.1)
    img_mean = d_res[measure]["img"].mean()
    img_sem = d_res[measure]["img"].sem()
    ax.plot(img_mean, label=f"{measure} image", color=img_color, lw=1.5)
    ax.fill_between(
        img_mean.index,
        img_mean - img_sem,
        img_mean + img_sem,
        alpha=0.5,
        color=img_color,
    )
    vid_mean = d_res[measure]["vid"].mean()
    vid_sem = d_res[measure]["vid"].sem()
    ax.plot(vid_mean, label=f"{measure} video", color=vid_color, lw=1.5)
    ax.fill_between(
        vid_mean.index,
        vid_mean - vid_sem,
        vid_mean + vid_sem,
        alpha=0.5,
        color=vid_color,
    )
    ax.set_ylabel(ylabel)
    ax.set_xlabel(xlabel)
    ax.set_xlim(0,5000)
    ax.yaxis.set_major_locator(MaxNLocator(integer=True))



def avrg_measure_along_t(
    df, measure, fov=True, seen=False, unseen=False, animate=False, inanimate=False, maxtime=5000
):
    vid_t = np.ones(maxtime) * np.nan
    img_t = np.ones(maxtime) * np.nan
    df = df[df["t"] < maxtime]
    condition = [True for i in range(len(df))]
    if fov:
        condition = condition * (df["em_rv"] == "FOV")
    if seen:
        condition = condition * (df["seen"] == 1)
    if unseen:
        condition = condition * (df["seen"] == 0)
    if animate:
        condition = condition * (df["animate"] == 1)
    if inanimate:
        condition = condition * (df["animate"] == 0)
    vid_res = df[condition * (df.video == 1)].groupby("t")[measure].mean()
    vid_t[: len(vid_res)] = vid_res
    img_res = df[condition * (df.video == 0)].groupby("t")[measure].mean()
    img_t[: len(img_res)] = img_res
    return vid_t, img_t  # , condition


def t_stats(values):
    """
    takes a data frame (values) and returns the t-statistic across rows
    """
    return np.nanmean(values, axis=0) / (
        np.nanstd(values, axis=0) / np.sqrt(values.shape[0])
    )

def find_clusters(values_to_compare, critical_value, ignore_inf=True):
    """
    find a cluster of values above the critial threshold
    """
    all_clusters = {}
    over_critical = abs(values_to_compare) >= critical_value
    over_critical_positions, n_clusters = ndimage.label(over_critical)

    for cluster in range(n_clusters):
        cluster_id = cluster + 1
        cluster_location = np.where(over_critical_positions == cluster_id)
        current_cluster = values_to_compare[cluster_location]
        if ignore_inf:
            current_cluster = current_cluster[abs(current_cluster) != np.inf]
        all_clusters[cluster] = {}
        all_clusters[cluster]["cluster_id"] = cluster_id
        all_clusters[cluster]["cluster_size"] = len(current_cluster)
        all_clusters[cluster]["cluster_weight"] = abs(np.nansum(current_cluster))
        if (
            all_clusters[cluster]["cluster_weight"] == np.inf
            or all_clusters[cluster]["cluster_weight"] == np.nan
        ):
            raise ValueError(
                f"The cluster weight could not be computed. "
                f"Cluster weight is {all_clusters[cluster]['cluster_weight']}"
            )

        all_clusters[cluster]["cluster_location"] = cluster_location
    return all_clusters



def cluster_based_permutation_test(condition_a, condition_b, critical_t=2.093, n_reps=1000, percentile=0.05, random_seed=1):
    np.random.seed(random_seed) # ; random.seed(random_seed)
    
    condition_difference = condition_a - condition_b

    # assert condition_difference.shape[0] > condition_difference.shape[1], "Condition difference should be a vector of shape (n_subj, n_timepoints)"
    t_values = t_stats(condition_difference)
    clusters = find_clusters(t_values, critical_t)
    cluster_df = pd.DataFrame.from_dict(clusters).T
    n_subjects = condition_difference.shape[0]
    # random_permutation_matrix = cbp.get_random_permutation_matrix(n_subjects, n_reps, random_seed)
    rand_sign_array = np.random.choice([-1, 1], size=(n_subjects, n_reps))
    # plt.imshow(rand_sign_array, aspect="auto"); plt.show()
    permutated_cluster_df = pd.DataFrame(columns=["clusterID", "nRep", "value"])

    # rep = 0 
    for rep in range(n_reps):
        permutated_data = condition_difference.mul(rand_sign_array[:, rep], axis=0)
        t_values_per = t_stats(permutated_data)
        clusters_per = find_clusters(t_values_per, critical_t)
        # print(len(clusters))
        if len(clusters_per) > 0:
            df_cluster_per = pd.DataFrame.from_dict(clusters_per).T
            largest_cluster = np.argmax(df_cluster_per["cluster_weight"])

            permutated_cluster_df.loc[rep, "clusterID"] = df_cluster_per["cluster_id"][
                largest_cluster
            ]
            permutated_cluster_df.loc[rep, "nRep"] = rep
            permutated_cluster_df.loc[rep, "value"] = df_cluster_per["cluster_weight"][
                largest_cluster
            ]
        else:
            permutated_cluster_df.loc[rep, 'clusterID'] = [0]
            permutated_cluster_df.loc[rep, 'nRep'] = rep
            permutated_cluster_df.loc[rep, 'value'] = [0]

    sorted_clusters = permutated_cluster_df["value"].values
    sorted_clusters.sort()
    percentile_cutoff = int((1 - percentile) * n_reps)
    cutoff_value = sorted_clusters[percentile_cutoff]
    cluster_over_thresh = cluster_df[cluster_df["cluster_weight"] > cutoff_value]
    print(f"#clusters over thres. ({cutoff_value}): {len(cluster_over_thresh)}")
    return cluster_over_thresh




