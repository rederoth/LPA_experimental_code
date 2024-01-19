import cv2
import numpy as np
import glob
import random
import pandas as pd


def getImages(path, shuffle=True):
    im_list = glob.glob(path + "/*.png")
    if shuffle:
        random.shuffle(im_list)

    return im_list


if __name__ == "__main__":

    expertname = input("Expert Name: ")  # "Nico"  # get from input...
    random.seed(expertname)
    d = {}

    todo_list = getImages("/home/nico/project_code/LPA_study/Stimuli")
    # Read image
    c_todo = len(todo_list)
    print(c_todo)

    for i in range(len(todo_list)):
        im = cv2.imread(todo_list[i])
        vidname = todo_list[i].split("/")[-1][:-4]

        # Select ROI
        r = cv2.selectROI(im)
        # Crop image
        imCrop = im[int(r[1]) : int(r[1] + r[3]), int(r[0]) : int(r[0] + r[2])]
        print(vidname, r)
        # Display cropped image
        # cv2.imshow("Image", imCrop)

        # store in dict
        d[vidname] = r

        c_todo -= 1
        print("still to do: ", c_todo)

    pd.DataFrame.from_dict(data=d, orient="index").to_csv(
        f"{expertname}_ratings.csv", header=False
    )
    cv2.waitKey(0)
