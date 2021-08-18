
# cnn(Convolutional Newral Network) in VHDL
cnnの推論部分をVHDLで実装を行う。

## 仕様
### Base Python
- ここのPython実装のMNISTの推論部分をVHDL化することが目標。
  - [FPGA で始めるエッジディープラーニング (2) | ACRi Blog](https://www.acri.c.titech.ac.jp/wordpress/archives/5786)
- 上PythonではFloat実装なので論理実装しやすいように量子化(Quantize, int化)を行う。
- 大きく分けて4ブロック。
  - 全結合層
  - 畳み込み層
  - プーリング層
  - 活性化関数
- 各層間のI/FはValid-Ready+Dataのシンプルに。
  - 勝手にpipingと呼んでる。

### 量子化
RTLで扱いやすいように、Pythonでは量子化を行ったもので学習と推論を行う。  
(量子化前と比べ、正答率は多少落ちた)  

- [How to Quantize an MNIST network to 8 bits in Pytorch from scratch (No retraining required). | by Karanbir Chahal | Medium](https://karanbirchahal.medium.com/how-to-quantise-an-mnist-network-to-8-bits-in-pytorch-no-retraining-required-from-scratch-39f634ac8459)
  - [quantisation.ipynb - Colaboratory](https://colab.research.google.com/drive/1oDfcLRz2AIgsclkXJHj-5wMvbylr4Nxz#scrollTo=M5xNLrchrI6u)

- [(beta) Static Quantization with Eager Mode in PyTorch — PyTorch Tutorials 1.9.0+cu102 documentation](https://pytorch.org/tutorials/advanced/static_quantization_tutorial.html)

### I/F
- [組み込み屋の為のVerilog入門 その5 VALID&READYのハンドシェーク: Ryuzのブログ](http://ryuz.txt-nifty.com/blog/2012/09/verilog-s-c79f.html)
  - 途中でみつけたので今回はごちゃごちゃやってる。

### 他
- 色々できるように、パラメタライズしておく。
- Weight等のパラメータは、トップ階層からgenericで渡す。
- 1次元配列のみ使用。  
  - 2次元配列は、1次元配列を配列サイズから疑似2次元として扱う。

## 実行環境
### RTL側
- Smulator: Model Sim - Intel FPGA Starter Edition
- Run: test/run_modelsim.sh
  - 検証は、Python側でWeight等のパラメータと各層の入力データを出力。
  - 入力データをRTLに貼り付けて、出力データと期待値の比較を行っている。

### Python側
- Python Version: 3.6.9
- Pytorch: 1.6,0
- Run: py/q/cnn_predict_q.py

## working
- 全結合層(Linear)  
  - 実装・検証完了  
  - RTL: src/piping_linear.vhd  
  - TB: test/piping_linear_tb*.vhd  
- 畳み込み層(Conv2d)  
  - 実装・検証完了  
  - RTL: src/piping_conv.vhd  
  - TB: test/piping_conv_tb*.vhd  
- プーリング層(MaxPool2d)  
  - 未着手  
- 活性化関数(ReLu)  
  - 未着手
- TOP
  - 未着手
- AXI I/F
  - 未着手


## 全結合層(Linear)
### 式

```math
X=\begin{bmatrix}
x_{0} \\
\vdots \\
x_{i} \\
\vdots \\
x_{m} \\
\end{bmatrix}
\\
W=\begin{bmatrix}
w_{00} & \cdots & w_{0i} & \cdots & w_{0m}\\
\vdots & \ddots & & & \vdots \\
w_{i0} & & w_{ii} & & w_{im} \\
\vdots & & & \ddots & \vdots \\
w_{n0} & \cdots & w_{ni} & \cdots & w_{nm}
\end{bmatrix}
\\
B=\begin{bmatrix}
b_{0} \\
\vdots \\
b_{i} \\
\vdots \\
b_{n} \\
\end{bmatrix}
\\
SCL=scale >> scale\_shift
\\
Y=\begin{bmatrix}
y_{0} \\
\vdots \\
y_{i} \\
\vdots \\
y_{n} \\
\end{bmatrix}
\\
Y = (W \cdot X + B) \times SCL \\
\\
```

### パラメータ
Pythonでの学習結果より与える。  
RTLではトップからのパラメータ。  
Wnm: 整数配列, Python2次元からRTLでは1次元  
Bn: 整数配列, 1次元配列  
SCL.scale: 自然数  
SCL.shift: 自然数  

### RTL構成

RTL Hierarchy
| Instance(File) | | Description |
|-|-| - |
| (piping_linear.vhd) | | Linear Top |
| ├ | w_ram_control<br>(piping_ram_control.vhd) | W-RAM Control |
| ├ | w_ram<br>(ram1rw.vhd) | Weight RAM |
| ├ | piping_mul<br>(piping_mul.vhd) | Multiplier Weight |
| ├ | piping_sum<br>(piping_sum.vhd) | Sum |
| ├ | b_ram_control<br>(piping_ram_control.vhd) | B-RAM Control |
| ├ | b_ram<br>(ram1rw.vhd) | Bias RAM |
| ├ | piping_add<br>(piping_add.vhd) | Adder Bias |
| ├ | piping_scale<br>(piping_scale.vhd) | Scaling for Quantize |

## 畳み込み層(Conv2d)
### 式
```math
SCL=scale >> scale\_shift  \\
Y(i,j) = (\sum_{m} \sum_{n}W(m,n) \cdot X(i-m,j-n)) \times SCL
```
Quoted from [FPGA で始めるエッジディープラーニング (2) | ACRi Blog](https://www.acri.c.titech.ac.jp/wordpress/archives/5786)

### パラメータ
Pythonでの学習結果より与える。  
RTLではトップからのパラメータ。  
W: KERNEL_WEIGHT, 今回は3x3の整数配列。RTLでは1次元(9).  
SCL.scale: 自然数  
SCL.shift: 自然数  

### RTL構成

| Instance(File) | | Description |
|-|-| - |
| (piping_conv.vhd) | | Conv Top |
| ├ | piping_conv_line_buf<br>(piping_conv_line_buf.vhd) | Line Bufffer |
| ├ | piping_conv_buf<br>(piping_conv_buf.vhd) | Pix Buffer |
| ├ | piping_conv_cal<br>(piping_conv_cal.vhd) | Calc, Multiplier Weight |
| ├ | piping_scale<br>(piping_scale.vhd) | Scale |

