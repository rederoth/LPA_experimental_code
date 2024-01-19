import cv2
import numpy as np
import glob
import random
import pandas as pd

savepath = "/home/nico/project_code/LPA_study/ExpertRatings/images_with_ratings"

if __name__ == "__main__":
    
    # get all ratings
    expert_list = glob.glob("/home/nico/project_code/LPA_study/ExpertRatings/*.csv")
    for expert_str in expert_list:
        expert_name = expert_str.split('/')[-1][:-12]
        print(expert_name)
        df = pd.read_csv(expert_str, header=None)
        for i in range(len(df)):
            im_path = f"/home/nico/project_code/LPA_study/Stimuli/{df.iloc[i][0]}.png"
            im = cv2.imread(im_path)
            r = [int(df.iloc[i][1]), int(df.iloc[i][2]), int(df.iloc[i][3]), int(df.iloc[i][4])]
            print(r)
            # imCrop = im[int(r[1]) : int(r[1] + r[3]), int(r[0]) : int(r[0] + r[2])]
            # cv2.imshow("Crop", imCrop)
            cv2.rectangle(im, (r[0],r[1]), (r[0]+r[2],r[1]+r[3]), (255,0,0), 3)
            cv2.imwrite(f"{savepath}/{df.iloc[i][0]}_{expert_name}.png", im)
        # cv2.waitKey(0)




