# Windows 安装支持 GPU 的 opencv-python

## 确保 Python 是 64 位

```sh
python -c "import sys,platform; print(sys.version); print(platform.architecture())"
```

## 安装 CUDA Toolkit + cuDNN

参考：[Windows 安装 CUDA Toolkit + cuDNN](windows-cuda-cudnn.md)

## 卸载 CPU build 版本的 opencv-python

```sh
pip uninstall -y opencv-python opencv-contrib-python
# pip uninstall -y opencv-python-headless opencv-contrib-python-headless
# pip uninstall -y opencv-python-rolling opencv_contrib_python_rolling
```

## 安装 CUDA 版本的 opencv-python

访问 `cudawarped/opencv-python-cuda-wheels`：
- 搜索对应 CUDA 版本，以及 `win_amd64`
- https://github.com/cudawarped/opencv-python-cuda-wheels/releases

`cuda 12.9` + `cudnn 9.10.2`：
- https://github.com/cudawarped/opencv-python-cuda-wheels/releases/download/4.12.0.88/opencv_contrib_python-4.12.0.88-cp37-abi3-win_amd64.whl
- `4.12.0.88: OpenCV python wheels built against CUDA 12.9, Nvidia Video Codec SDK 13.0 and cuDNN 9.10.2.`

`cuda 12.2` + `cudnn 8.9.3`：
- https://github.com/cudawarped/opencv-python-cuda-wheels/releases/download/4.8.0.20230804/opencv_contrib_python_rolling-4.8.0.20230804-cp36-abi3-win_amd64.whl
- `OpenCV python wheels built against CUDA 12.2, Nvidia Video Codec SDK 12.1 and cuDNN 8.9.3.`

下载并安装：

```sh
# cd <下载目录>
pip install opencv_contrib_python-4.12.0.88-cp37-abi3-win_amd64.whl
```

## 检查是否安装成功

检查 OpenCV 版本信息：

```sh
python -c "import cv2; print(cv2.getBuildInformation())"
```

检查是否支持 CUDA：

```sh
python -c "import cv2; print('CUDA devices:', cv2.cuda.getCudaEnabledDeviceCount())"
```

输出形如：

```sh
CUDA devices: 1
```