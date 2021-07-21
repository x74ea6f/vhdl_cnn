## [FPGA で始めるエッジディープラーニング (2) | ACRi Blog](https://www.acri.c.titech.ac.jp/wordpress/archives/5786)
import torch
import torch.nn as nn
import torchvision
import torchvision.transforms as transforms
from sklearn.metrics import accuracy_score, confusion_matrix

## ADD Q
from torch.quantization import QuantStub, DeQuantStub

# 1. ネットワークモデルの定義
class Net(nn.Module):
    def __init__(self, num_output_classes=10):
        super(Net, self).__init__()

        # 入力は28x28 のグレースケール画像 (チャネル数=1)
        # 出力が8チャネルとなるような畳み込みを行う
        self.conv1 = nn.Conv2d(in_channels=1, out_channels=4, kernel_size=3, padding=1)

        # 活性化関数はReLU
        self.relu1 = nn.ReLU(inplace=True)

        # 画像を28x28から14x14に縮小する
        self.pool1 = nn.MaxPool2d(kernel_size=2, stride=2)

        # 4ch -> 8ch, 14x14 -> 7x7
        self.conv2 = nn.Conv2d(in_channels=4, out_channels=8, kernel_size=3, padding=1)
        self.relu2 = nn.ReLU(inplace=True)
        self.pool2 = nn.MaxPool2d(kernel_size=2, stride=2)

        # 全結合層
        # 8chの7x7画像を1つのベクトルとみなし、要素数32のベクトルまで縮小
        self.fc1 = nn.Linear(8 * 7 * 7, 32)
        self.relu3 = nn.ReLU(inplace=True)

        # 全結合層その2
        # 出力クラス数まで縮小
        self.fc2 = nn.Linear(32, num_output_classes)

        ## ADD Q
        self.quant = QuantStub()
        self.dequant = DeQuantStub()

        ## to_csv X
        self.save_csv = None

    def forward(self, x):
        ## ADD Q
        x = self.quant(x)

        # 1層目の畳み込み
        # 活性化関数 (activation) はReLU
        x = self.conv1(x)
        x = self.relu1(x)

        # 縮小
        x = self.pool1(x)

        # 2層目+縮小
        x = self.conv2(x)
        x = self.relu2(x)
        x = self.pool2(x)

        # フォーマット変換 (Batch, Ch, Height, Width) -> (Batch, Ch)
        ##TMP x = x.view(x.shape[0], -1)
        x = x.reshape([x.shape[0], -1])

        # 全結合層
        if self.save_csv: self.save_csv(x, "x_fc1_pre.q.csv")
        x = self.fc1(x)
        if self.save_csv: self.save_csv(x, "x_fc1_out.q.csv")
        x = self.relu3(x)
        if self.save_csv: self.save_csv(x, "x_fc2_pre.q.csv")
        x = self.fc2(x)
        if self.save_csv: self.save_csv(x, "x_fc2_out.q.csv")

        ## ADD Q
        x = self.dequant(x)

        return x

