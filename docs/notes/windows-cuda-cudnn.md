# Windows 安装 CUDA Toolkit + cuDNN

cuDNN 可能需要登录账号+填写个人信息才能下载。

## CUDA 12.9 + cuDNN 9.10.2

CUDA Toolkit 12.9 Downloads：
- https://developer.nvidia.com/cuda-12-9-0-download-archive
- https://developer.nvidia.com/cuda-12-9-0-download-archive?target_os=Windows&target_arch=x86_64&target_version=10&target_type=exe_local

cuDNN 9.10.2：
- https://developer.nvidia.com/cudnn-9-10-2-download-archive
- https://developer.nvidia.com/cudnn-9-10-2-download-archive?target_os=Windows&target_arch=x86_64&target_version=10&target_type=exe_local

## CUDA 12.2 + cuDNN 8.9.3

CUDA Toolkit 12.2 Downloads | NVIDIA Developer：
- https://developer.nvidia.com/cuda-12-2-0-download-archive
- https://developer.nvidia.com/cuda-12-2-0-download-archive?target_os=Windows&target_arch=x86_64&target_version=10&target_type=exe_local

cuDNN v8.9.3 (July 11th, 2023), for CUDA 12.x：
- https://developer.nvidia.com/rdp/cudnn-archive
- https://developer.nvidia.com/downloads/compute/cudnn/secure/8.9.3/local_installers/12.x/cudnn-windows-x86_64-8.9.3.28_cuda12-archive.zip

## 点击安装

CUDA 默认安装路径：
- `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.x`
- 一开始会提示你解压位置，这个不是最终安装路径，可以选为 `D:\CUDA12X`，安装好后这个文件夹会自动删除
- 为了不占用太多C盘空间，可以将安装路径设为：`D:\CUDA-12.x`
- 安装好后，可以在系统环境变量的 PATH 中看到新增了 `D:\CUDA-12.x\bin` 和 `D:\CUDA-12.x\libnvvp`

cuDNN 默认安装路径：
- `C:\Program Files\NVIDIA\CUDNN\v9.x`
- 为了不占用太多C盘空间，可以将安装路径设为：`D:\CUDNN-9.x`
- 需要把 Development, Runtime, Samples 都设为同一个路径
- 解压后需要手动将文件复制到 CUDA 安装目录下对应的文件夹中

## 复制 cuDNN 文件到 CUDA 路径

将下载好的 cuDNN 文件放到 CUDA 安装目录的对应路径：
- `CUDNN-9.10\bin\12.9\*.dll` -> `CUDA-12.9\bin\*.dll`
- `CUDNN-9.10\include\12.9\*.h` -> `CUDA-12.9\include\*.h`
- `CUDNN-9.10\lib\12.9\x64\*.lib` -> `CUDA-12.9\lib\x64\*.lib`

## 检查是否安装成功

```sh
nvidia-smi
```

输出形如：

```sh
Mon Dec  8 07:13:38 2025
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 576.02                 Driver Version: 576.02         CUDA Version: 12.9     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                  Driver-Model | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
...
```

```sh
nvcc --version
```

输出形如：

```sh
nvcc: NVIDIA (R) Cuda compiler driver
Copyright (c) 2005-2025 NVIDIA Corporation
Built on Wed_Apr__9_19:29:17_Pacific_Daylight_Time_2025
Cuda compilation tools, release 12.9, V12.9.41
Build cuda_12.9.r12.9/compiler.35813241_0
```