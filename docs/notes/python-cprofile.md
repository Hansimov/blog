# Python 测试性能

::: tip SnakeViz: https://jiffyclub.github.io/snakeviz/
:::

## 用 cProfile 测试性能

脚本：

```sh
python -m cProfile -o cprofile.prof example.py
```

模块：

```sh
python -m cProfile -o cprofile.prof -m modules.example
```

## 用 snakeviz 可视化

安装：

```sh
pip install snakeviz
```

在网页显示可视化结果：

```sh
snakeviz cprofile.prof -H 0.0.0.0 -p 13579
```

访问打印出来的网页地址，形如：

```sh
http://<hostname>:13579/snakeviz/<path_to_cprofile>/cprofile.prof
```
