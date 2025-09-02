# Ubuntu 设置 GPU 风扇速度

## 查看所有风扇相关设置

```sh
DISPLAY=:0 nvidia-settings -q all | grep -i fan
```

<details>
<summary>输出形如：</summary>

```sh
  Attribute 'GPUFanControlState' (xeon:0[gpu:0]): 1.
    'GPUFanControlState' is a boolean attribute; valid values are: 1 (on/true) and 0 (off/false).
    'GPUFanControlState' can use the following target types: GPU.
  Attribute 'GPUFanControlState' (xeon:0[gpu:1]): 1.                                                                                                                            [55/4124]
    ... (同上)
Attributes queryable via xeon:0[fan:0]:
  Attribute 'GPUTargetFanSpeed' (xeon:0[fan:0]): 30.
    The valid values for 'GPUTargetFanSpeed' are in the range 0 - 100 (inclusive).
    'GPUTargetFanSpeed' can use the following target types: Fan.
  Attribute 'GPUCurrentFanSpeed' (xeon:0[fan:0]): 30.
    The valid values for 'GPUCurrentFanSpeed' are in the range 0 - 100 (inclusive).
    'GPUCurrentFanSpeed' is a read-only attribute.
    'GPUCurrentFanSpeed' can use the following target types: Fan.
  Attribute 'GPUCurrentFanSpeedRPM' (xeon:0[fan:0]): 1998.
    'GPUCurrentFanSpeedRPM' is an integer attribute.
    'GPUCurrentFanSpeedRPM' is a read-only attribute.
    'GPUCurrentFanSpeedRPM' can use the following target types: Fan.
  Attribute 'GPUFanControlType' (xeon:0[fan:0]): 2.
    'GPUFanControlType' is an integer attribute.
    'GPUFanControlType' is a read-only attribute.
    'GPUFanControlType' can use the following target types: Fan.
  Attribute 'GPUFanTarget' (xeon:0[fan:0]): 0x00000007.
    'GPUFanTarget' is a bitmask attribute.
    'GPUFanTarget' is a read-only attribute.
    'GPUFanTarget' can use the following target types: Fan.
Attributes queryable via xeon:0[fan:1]:
  ... (同上)
Attributes queryable via xeon:0[fan:2]:
  Attribute 'GPUTargetFanSpeed' (xeon:0[fan:2]): 30.
    The valid values for 'GPUTargetFanSpeed' are in the range 0 - 100 (inclusive).
    'GPUTargetFanSpeed' can use the following target types: Fan.
  Attribute 'GPUCurrentFanSpeed' (xeon:0[fan:2]): 0.
    The valid values for 'GPUCurrentFanSpeed' are in the range 0 - 100 (inclusive).
    'GPUCurrentFanSpeed' is a read-only attribute.
    'GPUCurrentFanSpeed' can use the following target types: Fan.
  Attribute 'GPUCurrentFanSpeedRPM' (xeon:0[fan:2]): 0.
    'GPUCurrentFanSpeedRPM' is an integer attribute.
    'GPUCurrentFanSpeedRPM' is a read-only attribute.
    'GPUCurrentFanSpeedRPM' can use the following target types: Fan.
  Attribute 'GPUFanControlType' (xeon:0[fan:2]): 2.
    'GPUFanControlType' is an integer attribute.
    'GPUFanControlType' is a read-only attribute.
    'GPUFanControlType' can use the following target types: Fan.
  Attribute 'GPUFanTarget' (xeon:0[fan:2]): 0x00000007.
    'GPUFanTarget' is a bitmask attribute.
    'GPUFanTarget' is a read-only attribute.
    'GPUFanTarget' can use the following target types: Fan.
Attributes queryable via xeon:0[fan:3]:
  ... (同上)
```

</details>

## 查看风扇信息

```sh
DISPLAY=:0 nvidia-settings -q fans
```

输出形如：

```sh
4 Fans on xeon:0
    [0] xeon:0[fan:0] (Fan 0)
      Has the following name:
        FAN-0
    [1] xeon:0[fan:1] (Fan 1)
      Has the following name:
        FAN-1
    [2] xeon:0[fan:2] (Fan 2)
      Has the following name:
        FAN-2
    [3] xeon:0[fan:3] (Fan 3)
      Has the following name:
        FAN-3
```

## 查看 GPU 风扇控制状态

```sh
DISPLAY=:0 nvidia-settings -q GPUFanControlState
```

输出形如：
```sh
  Attribute 'GPUFanControlState' (xeon:0[gpu:0]): 0.
    'GPUFanControlState' is a boolean attribute; valid values are: 1 (on/true) and 0 (off/false).
    'GPUFanControlState' can use the following target types: GPU.
  Attribute 'GPUFanControlState' (xeon:0[gpu:1]): 0.
    'GPUFanControlState' is a boolean attribute; valid values are: 1 (on/true) and 0 (off/false).
    'GPUFanControlState' can use the following target types: GPU.
```

* 这里两张 GPU 都是 `0`，表示风扇控制未开启

## 设置 GPU 风扇控制状态

```sh
DISPLAY=:0 nvidia-settings -a '[gpu:0]/GPUFanControlState=1'
DISPLAY=:0 nvidia-settings -a '[gpu:1]/GPUFanControlState=1'
```

输出形如：

```sh
  Attribute 'GPUFanControlState' (xeon:0[gpu:0]) assigned value 1.
  Attribute 'GPUFanControlState' (xeon:0[gpu:1]) assigned value 1.
```

查看修改是否成功：

```sh
DISPLAY=:0 nvidia-settings -q GPUFanControlState
```

输出形如：

```sh
  Attribute 'GPUFanControlState' (xeon:0[gpu:0]): 1.
    'GPUFanControlState' is a boolean attribute; valid values are: 1 (on/true) and 0 (off/false).
    'GPUFanControlState' can use the following target types: GPU.
  Attribute 'GPUFanControlState' (xeon:0[gpu:1]): 1.
    'GPUFanControlState' is a boolean attribute; valid values are: 1 (on/true) and 0 (off/false).
    'GPUFanControlState' can use the following target types: GPU.
```

* 可以看到两张 GPU 都是 `1`，表示风扇控制已开启


## 查看风扇当前速度

```sh
DISPLAY=:0 nvidia-settings -q '[fan:0]/GPUCurrentFanSpeed'
DISPLAY=:0 nvidia-settings -q '[fan:2]/GPUCurrentFanSpeed'
```

输出形如：

```sh
  Attribute 'GPUCurrentFanSpeed' (xeon:0[fan:0]): 30.
    The valid values for 'GPUCurrentFanSpeed' are in the range 0 - 100 (inclusive).
    'GPUCurrentFanSpeed' is a read-only attribute.
    'GPUCurrentFanSpeed' can use the following target types: Fan.
  Attribute 'GPUCurrentFanSpeed' (xeon:0[fan:2]): 0.
    The valid values for 'GPUCurrentFanSpeed' are in the range 0 - 100 (inclusive).
    'GPUCurrentFanSpeed' is a read-only attribute.
    'GPUCurrentFanSpeed' can use the following target types: Fan.
```

* 第一张 GPU 风扇（fan:0/1）转速为 30%
* 第二张 GPU 风扇（fan:2/3）转速为 0%（未转动）

## 设置风扇目标速度

```sh
DISPLAY=:0 nvidia-settings -a '[fan:0]/GPUTargetFanSpeed=35'
DISPLAY=:0 nvidia-settings -a '[fan:1]/GPUTargetFanSpeed=35'
DISPLAY=:0 nvidia-settings -a '[fan:2]/GPUTargetFanSpeed=30'
DISPLAY=:0 nvidia-settings -a '[fan:3]/GPUTargetFanSpeed=30'
```

输出形如：

```sh
  Attribute 'GPUTargetFanSpeed' (xeon:0[fan:0]) assigned value 35.
  Attribute 'GPUTargetFanSpeed' (xeon:0[fan:1]) assigned value 35.
  Attribute 'GPUTargetFanSpeed' (xeon:0[fan:2]) assigned value 30.
  Attribute 'GPUTargetFanSpeed' (xeon:0[fan:3]) assigned value 30.
```

查看修改是否成功：

```sh
DISPLAY=:0 nvidia-settings -q '[fan:0]/GPUTargetFanSpeed'
DISPLAY=:0 nvidia-settings -q '[fan:2]/GPUTargetFanSpeed'
```

或者直接查看显卡信息：

```sh
nvidia-smi
```

## 一键配置

```sh
cd downloads
wget https://raw.githubusercontent.com/Hansimov/blog/main/docs/notes/scripts/gpu_fan.sh -O gpu_fan.sh
chmod +x gpu_fan.sh
./gpu_fan.sh
```

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/gpu_fan.sh
:::

<<< @/notes/scripts/gpu_fan.sh


## 常见问题1：无法修改部分属性

::: warning drivers - Unable to Control NVIDIA Fan Speed - Ask Ubuntu
https://askubuntu.com/questions/1411667/unable-to-control-nvidia-fan-speed
:::

### 修改 Xwrapper.config

```sh
sudo nano /etc/X11/Xwrapper.config
```

在 `allowed_users=console` 上面一行添加 `needs_root_rights=yes`：


```sh{15}
# Xwrapper.config (Debian X Window System server wrapper configuration file)
#
# This file was generated by the post-installation script of the
# xserver-xorg-legacy package using values from the debconf database.
#
# See the Xwrapper.config(5) manual page for more information.
#
# This file is automatically updated on upgrades of the xserver-xorg-legacy
# package *only* if it has not been modified since the last upgrade of that
# package.
#
# If you have edited this file but would like it to be automatically updated
# again, run the following command as root:
#   dpkg-reconfigure xserver-xorg-legacy
needs_root_rights=yes
allowed_users=console
```

### 重启 X server

可以直接重启服务器，`sudo reboot`。不过也可以试试单独重启 X server。

查看 X server 服务状态：

```sh
sudo systemctl status display-manager
```

输出形如：

```sh
● gdm.service - GNOME Display Manager
     Loaded: loaded (/lib/systemd/system/gdm.service; static)
     Active: active (running) since Tue 2025-08-26 08:09:03 CST; 36min ago
    Process: 4273 ExecStartPre=/usr/share/gdm/generate-config (code=exited, status=0/SUCCESS)
   Main PID: 4294 (gdm3)
      Tasks: 3 (limit: 629145)
     Memory: 123.7M
        CPU: 4.061s
     CGroup: /system.slice/gdm.service
             └─4294 /usr/sbin/gdm3

8月 26 08:09:02 xeon systemd[1]: Starting GNOME Display Manager...
8月 26 08:09:03 xeon systemd[1]: Started GNOME Display Manager.
8月 26 08:09:04 xeon gdm-autologin][4302]: gkr-pam: no password is available for user
8月 26 08:09:04 xeon gdm-autologin][4302]: pam_unix(gdm-autologin:session): session opened for user asimov(uid=1000) by (uid=0)
8月 26 08:09:04 xeon gdm-autologin][4302]: gkr-pam: gnome-keyring-daemon started properly
```

* 可以看到，X server 使用的是 `gdm3`。

重启 X server：

```sh
sudo systemctl restart gdm3
```

## 常见问题2：4090设置风扇速度有效，3080设置无效

GPT5 说有可能是部分显卡有零转速模式（Zero RPM Mode），在低温时风扇会自动停转。

待解决。