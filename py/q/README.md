
0. 量子化モデル
cnn_q.py

0. 学習
```
python3 cnn_train_q.py
```

0. 学習モデルからパラメータをcsv抽出.
あと推論も。
```
python3 cnn_predict_q.py 1
```

0. パラメータをRTLに実装しやすいように変換。
誤差を見積もり。

```
## Linear用。
python3 test_linear.py
```

0. RTLのモデルをPYに実装。
##TODO
