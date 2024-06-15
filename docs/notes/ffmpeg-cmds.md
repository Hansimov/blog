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