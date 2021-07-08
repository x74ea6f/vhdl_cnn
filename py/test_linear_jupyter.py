#%%
import numpy as np
import pandas as pd

#%%
##-- int8
x_pre = pd.read_csv("./py/x_pre.csv", header=None).to_numpy()
w = pd.read_csv("./py/fc1_w.csv", header=None).to_numpy()
b = pd.read_csv("./py/fc1_b.csv", header=None).to_numpy()
exp = pd.read_csv("./py/x_fc1_out.csv", header=None).to_numpy()

x_pre = x_pre.squeeze()
b = b.squeeze()

print("X_PRE", x_pre.shape)
print("W", w.shape)
print("B", b.shape)

x_s = np.dot(w, x_pre)
##TMP x_s = np.dot(w, x_pre) + b
x_s = np.round(x_s/128)
print("X_S", x_s.shape)
print(x_s)
print(x_s / exp)


#%%
##-- float
x_pre_org = pd.read_csv("./py/x_pre.org.csv", header=None).to_numpy()
w_org = pd.read_csv("./py/fc1_w.org.csv", header=None).to_numpy()
b_org = pd.read_csv("./py/fc1_b.org.csv", header=None).to_numpy()
exp_org = pd.read_csv("./py/x_fc1_out.org.csv", header=None).to_numpy()

x_pre_org = x_pre_org.squeeze()
b_org = b_org.squeeze()

print("X_PRE", x_pre_org.shape)
print("W", w_org.shape)
print("B", b_org.shape)

x_s_org = np.dot(w_org, x_pre_org)
##TMP x_s = np.dot(w_org, x_pre_org) + b_org
print("X_S", x_s_org.shape)
print(x_s_org)
print(x_s_org - exp_org)

#%%
## 
print("----")
print(x_s / x_s_org)
print("----")

print("W", pd.DataFrame(w.reshape([-1])).describe())
print("std", pd.DataFrame(w.reshape([-1])).std(axis=0))
std=pd.DataFrame(w.reshape([-1])).std().values
w2 = w / (std)
print("W2", pd.DataFrame(w2.reshape([-1])).describe())

w3 = np.clip(w2*128, -127, 127)
print("W3", pd.DataFrame(w3.reshape([-1])).describe())

#%%
## 
print("----")
x_s_w3 = np.dot(w3, x_pre)
x_s_w3 = np.round(x_s_w3/128)
print("X_S", x_s_w3.shape)
print(x_s_w3)
print("----")
print(x_s / x_s_org)
print(x_s_w3 / x_s_org)


# %%
