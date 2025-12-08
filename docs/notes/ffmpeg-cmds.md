# ffmpeg 常用命令

## 安装

```sh
sudo apt install ffmpeg
```

## 从 mp4 中提取 wav

```sh
ffmpeg -y -i "BV1hZ421g7xC.mp4" -vn -acodec pcm_s16le -ar 44100 -ac 2 "BV1hZ421g7xC.wav"
```

其中：

- `-i "input.mp4"`：输入文件为 `input.mp4`
- `-vn`：不包含视频流
- `-acodec pcm_s16le`：音频编码为 `pcm_s16le`
- `-ar 44100`：音频采样率为 `44100`
  - 降低该值以减小文件，例如可取 `22050`, `16000`
- `-ac 2`：音频通道数为 `2`

::: tip See: ffmpeg - Extracting wav from mp4 while preserving the highest possible quality - Super User
* https://superuser.com/questions/609740/extracting-wav-from-mp4-while-preserving-the-highest-possible-quality

ffmpeg - Wav audio file compression not working - Stack Overflow
* https://stackoverflow.com/questions/34520694/wav-audio-file-compression-not-working
:::

## 从 mp4 中提取 mp3

```sh
ffmpeg -y -i "BV1hZ421g7xC.mp4" -vn "BV1hZ421g7xC.mp3"
```

## 将 mkv 转成 mp4

```sh
ffmpeg -y -ss 5 -i "2025-12-08 19-35-22.mkv" -an -vf "scale=-2:720" -c:v libx264 -crf 20 -r 60 -preset medium "2025-12-08_19-35-22_720p.mp4"
```

- `-y`：覆盖输出文件而不提示
- `-ss 5`：从第 5 秒开始读取，也即去掉前 5 秒
- `-an`：不包含音频流
- `-vf "scale=-2:720"`：将视频高度缩放到 720p，宽度按比例缩放且为偶数
- `-c:v`：使用 H.264 编码输出 MP4
- `-crf 20`：指定视频质量，范围为 `0-51`，值越小质量越高，`18-28` 是常用范围
- `-r 60`：设置输出视频的帧率为 60 FPS
- `-preset medium`：编码速度与压缩率的平衡，默认是 `medium`
  - 常用值有 `ultrafast`, `superfast`, `veryfast`, `faster`, `fast`, `medium`, `slow`, `slower`, `veryslow`
