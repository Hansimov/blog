# 安装 RocksDB

::: tip rocksdb/INSTALL.md at master · facebook/rocksdb
  * https://github.com/facebook/rocksdb/blob/master/INSTALL.md
:::

## Ubuntu 安装和编译

安装依赖：

```sh
sudo apt-get update
sudo apt-get install -y build-essential git cmake libgflags-dev clang-format libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev
```

克隆 RocksDB 仓库：

```sh
cd ~/repos
git clone https://github.com/facebook/rocksdb.git
cd rocksdb
```

（推荐）编译共享库并安装：（生成 `.so` 文件）

```sh
# make clean
PORTABLE=0 DEBUG_LEVEL=0 make shared_lib -j16
sudo DEBUG_LEVEL=0 make install-shared 
```

（或者）编译静态库并安装：（生成 `.a` 文件）

```sh
PORTABLE=0 DEBUG_LEVEL=0 make static_lib -j16
sudo DEBUG_LEVEL=0 make install-static
```

默认安装到 `usr/local/lib`，可以检查是否正确安装：

```sh
ls -hal /usr/local/lib/librocksdb.*
```

输出形如：

```sh
/usr/local/lib/librocksdb.so
/usr/local/lib/librocksdb.so.10
/usr/local/lib/librocksdb.so.10.5
/usr/local/lib/librocksdb.so.10.5.0
```

确保动态链接库能被加载：

```sh
sudo ldconfig
```

## 安装 Python 绑定

<details> <summary>过时的库</summary>

::: warning twmht/python-rocksdb: Python bindings for RocksDB
* https://github.com/twmht/python-rocksdb

Unable to install python-rocksdb · Issue #111 · twmht/python-rocksdb
* https://github.com/twmht/python-rocksdb/issues/111

trK54Ylmz/rocksdb-py: Python bindings for RocksDB written in Rust.
* https://github.com/trK54Ylmz/rocksdb-py

rocksdb-py · PyPI
* https://pypi.org/project/rocksdb-py
:::

</details>

::: tip rocksdict/RocksDict: Python fast on-disk dictionary / RocksDB & SpeeDB Python binding
* https://github.com/rocksdict/RocksDict/tree/main
* https://github.com/rocksdict/RocksDict/blob/main/src/options.rs

rocksdict API documentation
  * https://rocksdict.github.io/RocksDict/rocksdict.html
:::

```sh
pip install rocksdict
```

使用方法参见：[sedb.rocks](https://github.com/Hansimov/sedb/blob/main/src/sedb/rocks.py)