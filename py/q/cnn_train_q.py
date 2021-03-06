## [FPGA で始めるエッジディープラーニング (2) | ACRi Blog](https://www.acri.c.titech.ac.jp/wordpress/archives/5786)
import torch
import torch.nn as nn
import torchvision
import torchvision.transforms as transforms
from sklearn.metrics import accuracy_score, confusion_matrix

## ADD Q
from torch.quantization import QuantStub, DeQuantStub

from cnn_q import Net as Net


## # 1. ネットワークモデルの定義
## class Net(nn.Module):
##     def __init__(self, num_output_classes=10):
##         super(Net, self).__init__()
## 
##         # 入力は28x28 のグレースケール画像 (チャネル数=1)
##         # 出力が8チャネルとなるような畳み込みを行う
##         self.conv1 = nn.Conv2d(in_channels=1, out_channels=4, kernel_size=3, padding=1)
## 
##         # 活性化関数はReLU
##         self.relu1 = nn.ReLU(inplace=True)
## 
##         # 画像を28x28から14x14に縮小する
##         self.pool1 = nn.MaxPool2d(kernel_size=2, stride=2)
## 
##         # 4ch -> 8ch, 14x14 -> 7x7
##         self.conv2 = nn.Conv2d(in_channels=4, out_channels=8, kernel_size=3, padding=1)
##         self.relu2 = nn.ReLU(inplace=True)
##         self.pool2 = nn.MaxPool2d(kernel_size=2, stride=2)
## 
##         # 全結合層
##         # 8chの7x7画像を1つのベクトルとみなし、要素数32のベクトルまで縮小
##         self.fc1 = nn.Linear(8 * 7 * 7, 32)
##         self.relu3 = nn.ReLU(inplace=True)
## 
##         # 全結合層その2
##         # 出力クラス数まで縮小
##         self.fc2 = nn.Linear(32, num_output_classes)
## 
##         ## ADD Q
##         self.quant = QuantStub()
##         self.dequant = DeQuantStub()
##         
## 
##     def forward(self, x):
##         ## ADD Q
##         x = self.quant(x)
## 
##         # 1層目の畳み込み
##         # 活性化関数 (activation) はReLU
##         x = self.conv1(x)
##         x = self.relu1(x)
## 
##         # 縮小
##         x = self.pool1(x)
## 
##         # 2層目+縮小
##         x = self.conv2(x)
##         x = self.relu2(x)
##         x = self.pool2(x)
## 
##         # フォーマット変換 (Batch, Ch, Height, Width) -> (Batch, Ch)
##         x = x.view(x.shape[0], -1)
## 
##         # 全結合層
##         x = self.fc1(x)
##         x = self.relu3(x)
##         x = self.fc2(x)
## 
##         ## ADD Q
##         x = self.dequant(x)
## 
##         return x


net = Net()

# 2. データセットの読み出し法の定義
# MNIST の学習・テストデータの取得
trainset = torchvision.datasets.MNIST(root='../data', train=True, download=True, transform=transforms.ToTensor())
testset = torchvision.datasets.MNIST(root='../data', train=False, download=True, transform=transforms.ToTensor())

# データの読み出し方法の定義
# 1stepの学習・テストごとに16枚ずつ画像を読みだす
trainloader = torch.utils.data.DataLoader(trainset, batch_size=16, shuffle=True)
testloader = torch.utils.data.DataLoader(testset, batch_size=16, shuffle=False)


# 3. 学習
def train(net, trainloader):
    # ロス関数、最適化器の定義
    loss_func = nn.CrossEntropyLoss()
    optimizer = torch.optim.Adam(net.parameters(), lr=0.0001)
    
    # データセット内の全画像を10回使用するまでループ
    for epoch in range(10):
        running_loss = 0
    
        # データセット内でループ
        for i, data in enumerate(trainloader, 0):
            # 入力バッチの読み込み (画像、正解ラベル)
            inputs, labels = data
    
            # 最適化器をゼロ初期化
            optimizer.zero_grad()
    
            # 入力画像をモデルに通して出力ラベルを取得
            outputs = net(inputs)
    
            # 正解との誤差の計算 + 誤差逆伝搬
            loss = loss_func(outputs, labels)
            loss.backward()
    
            # 誤差を用いてモデルの最適化
            optimizer.step()
            running_loss += loss.item()
            if i % 1000 == 999:
                print('[%d, %5d] loss: %.3f' %
                      (epoch + 1, i + 1, running_loss / 1000))
                running_loss = 0.0

train(net, trainloader)

# 4. テスト
def evaluate(net, testloader, n=None):
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

ans, pred = evaluate(net, testloader)
print('accuracy:', accuracy_score(ans, pred))
print('confusion matrix:')
print(confusion_matrix(ans, pred))

def save_model(net):
    # 5. モデルの保存
    # PyTorchから普通に読み出すためのモデルファイル
    torch.save(net.state_dict(), 'model.pt')

    # libtorch (C++ API) から読み出すためのTorch Script Module を保存
    example = torch.rand(1, 1, 28, 28)
    traced_script_module = torch.jit.trace(net, example)
    traced_script_module.save('traced_model.pt')

save_model(net)
