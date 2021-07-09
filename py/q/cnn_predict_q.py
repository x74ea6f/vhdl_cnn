## [FPGA で始めるエッジディープラーニング (2) | ACRi Blog](https://www.acri.c.titech.ac.jp/wordpress/archives/5786)
import torch
import torch.nn as nn
import torchvision
import torchvision.transforms as transforms
from sklearn.metrics import accuracy_score, confusion_matrix
import pandas as pd
import numpy as np
import re

## ADD Q
from torch.quantization import QuantStub, DeQuantStub

from cnn_q import Net

import sys
eval_num = None
if len(sys.argv)>1:
    eval_num = int(sys.argv[1])

def save_csv(x: torch.Tensor, name: str):
    if x.dtype==torch.qint8 or x.dtype==torch.quint8:
        print(f"Scale({name}):{x.q_scale()}, DTYPE={x.dtype}")
        scale_name = re.sub(r"\.csv", "_scale.csv", name)
        pd.DataFrame([x.q_scale(),]).to_csv(scale_name, header=False, index=False)
        x = torch.int_repr(x)
    x_np = x.detach().numpy()
    x_df = pd.DataFrame(x_np)
    x_df.to_csv(name, header=False, index=False)


net = Net()
net.save_csv = save_csv

# 2. データセットの読み出し法の定義
# MNIST の学習・テストデータの取得
## trainset = torchvision.datasets.MNIST(root='../data', train=True, download=True, transform=transforms.ToTensor())
testset = torchvision.datasets.MNIST(root='../data', train=False, download=True, transform=transforms.ToTensor())

# データの読み出し方法の定義
# 1stepの学習・テストごとに16枚ずつ画像を読みだす
testloader = torch.utils.data.DataLoader(testset, batch_size=1, shuffle=False)
## trainloader = torch.utils.data.DataLoader(trainset, batch_size=16, shuffle=True)
## testloader = torch.utils.data.DataLoader(testset, batch_size=16, shuffle=False)

net.load_state_dict(torch.load('model.pt'))


net.qconfig = torch.quantization.default_qconfig
print(net.qconfig)
torch.quantization.prepare(net, inplace=True)
torch.quantization.convert(net, inplace=True)

## Show paramter
print("--ALL--")
print(net.state_dict().keys())
print("--FC1--")
print(net.fc1)
print("Weight:", net.fc1.weight().size())
#print(net.fc1.weight())
save_csv(net.fc1.weight().data, "fc1_w.q.csv");
print("Bias:", net.fc1.bias().size())
#print(net.fc1.bias())
save_csv(net.fc1.bias().data, "fc1_b.q.csv");

for k in net.state_dict().keys():
    print(f"---{k}---")
    print(net.state_dict()[k])
    try:
        print("Scale:", net.state_dict()[k].q_scale())
    except:
        pass
    

# 4. テスト
def evaluate(net, testloader, n=None):
    net.eval()
    ans = []
    pred = []
    for i, data in enumerate(testloader, 0):
        inputs, labels = data

        outputs = net(inputs)

        ans += labels.tolist()
        pred += torch.argmax(outputs, 1).tolist()

        if n is not None and n<i:
            break
    return ans, pred

ans, pred = evaluate(net, testloader, eval_num)
print('accuracy:', accuracy_score(ans, pred))
print('confusion matrix:')
print(confusion_matrix(ans, pred))

