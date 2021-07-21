
import numpy as np
import pandas as pd

##-- float
x_pre_org = pd.read_csv("x_pre.org.csv", header=None).to_numpy()
w_org = pd.read_csv("fc1_w.org.csv", header=None).to_numpy()
b_org = pd.read_csv("fc1_b.org.csv", header=None).to_numpy()
exp_org = pd.read_csv("x_fc1_out.org.csv", header=None).to_numpy()

x_pre_org = x_pre_org.squeeze()
b_org = b_org.squeeze()

print("X_PRE", x_pre_org.shape)
print("W", w_org.shape)
print("B", b_org.shape)

x_s_org = np.dot(w_org, x_pre_org)
##TMP x_s_org = np.dot(w_org, x_pre_org) + b_org
print("X_S", x_s_org.shape)
print(x_s_org)
print(x_s_org - exp_org)


##-- int8
## scale_x = (127 - (-127)) / (x_pre_org.max() - x_pre_org.min())
## offset_x = (x_pre_org.max() - x_pre_org.min()) / 2
## x_pre = np.clip(np.round((x_pre_org - offset_x) * scale_x), -127, 127)
x_pre = np.clip(np.round(x_pre_org * 128), -128, 127)
w = np.clip(np.round(w_org * 128), -128, 127)
b = np.clip(np.round(b_org * 128), -128, 127)
exp = np.clip(np.round(exp_org * 128), -128, 127)

x_s = np.dot(w, x_pre)
## x_s = np.round(x_s / scale_x + offset_x)
x_s = np.round(x_s / 128)
x_s = np.clip(x_s, -128, 127)
x_s = x_s + b
x_s = np.clip(x_s, -128, 127)
print("X_S", x_s.shape)
print(x_s)
print(x_s / exp)

