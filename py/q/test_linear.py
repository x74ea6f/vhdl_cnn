
import numpy as np
import pandas as pd
import math

def q_linear(x, w, b_scaled, scale_sft, scale_mul):
    x = np.dot(w,x)
    print("MAX,MIN", x.max(), x.min())
    print("PRE_B:", x)

    x = x + b_scaled
    print("PRE_SCALE:", x)

    x = x * scale_mul
    x = x*(2**-scale_sft)
    x = np.clip(np.round(x), 0, 255) ## to quint8
    return x

## B originを使う
def q_linear_b_org(x, w, b_scaled, scale_sft, scale_mul):
    ## b = b/scale
    ## b = np.clip(np.round(b), -127, 127) ## to qint8
    x = np.dot(w,x)

    x = x * scale_mul
    x = x*(2**-scale_sft)
    ## x = np.clip(np.round(x), -127, 127) ## to qint8
    print("MAX,MIN", x.max(), x.min())

    x = x + b_scaled

    ## x = x * scale_mul
    ## x = x*(2**-scale_sft)
    x = np.clip(np.round(x), 0, 255) ## to quint8
    return x

## Pytorch Original
def q_linear_org(x, w, b, scale=1.0):
    x = np.dot(w,x)
    x = x*scale
    x = x + b
    x = np.round(x)
    x = np.clip(x, 0, 255) ## to quint8
    return x

## X*Scale ≒ (X*mul)>>sft
## 0<scale<1, mul=int, sft=int
def scale_conv(scale, BIT=8): ## Mul=8bit
    s = math.log2(scale)
    sft = math.floor(-s)+BIT
    mul = round(2**(s+sft))
    scale_s = (2**(-sft))*mul
    if mul==(2**BIT):
        mul=1
        sft+=-BIT
    print("scale delta: ", scale - scale_s)
    return sft, mul

##-- q
x_pre_org = pd.read_csv("x_fc1_pre.q.csv", header=None).to_numpy()
w_org = pd.read_csv("fc1_w.q.csv", header=None).to_numpy()
b_org = pd.read_csv("fc1_b.q.csv", header=None).to_numpy()
exp_org = pd.read_csv("x_fc1_out.q.csv", header=None).to_numpy()
scale_org = pd.read_csv("fc1_w.q_scale.csv", header=None).to_numpy()

x_pre_org = x_pre_org.squeeze()
b_org = b_org.squeeze()
exp_org = exp_org.squeeze()

print("X_PRE", x_pre_org.shape)
print("W", w_org.shape)
print("B", b_org.shape)

## scaleをint8の乗算とシフトに置き換え。
scale_sft, scale_mul = scale_conv(scale_org)
print(f"Scale: sft={scale_sft}, mul={scale_mul}")
## bは、何故かfloatなのでscaleを先に乗算して、int8にする.
b_org_scaled = np.clip(np.round(b_org/scale_org), -127,127)
pd.DataFrame(b_org_scaled.astype(np.int8)).to_csv("fc1_b_scaled.q.csv", header=None, index=None)

## x_s_org = q_linear_org(x_pre_org, w_org, b_org, scale_org)
## x_s_org = q_linear_b_org(x_pre_org, w_org, b_org, scale_sft, scale_mul)
x_s_org = q_linear(x_pre_org, w_org, b_org_scaled, scale_sft, scale_mul)
print("X_S", x_s_org.shape)
print(x_s_org)
print(x_s_org - exp_org)

