# 安装使用 whisperX

## 下载安装 whisperX

```sh
git clone https://github.com/m-bain/whisperX.git
cd whisperX
pip install -r requirements.txt
pip install -e .
```

然后确保安装了 ffmpeg。

## 使用

```sh
whisperx --model large-v2 --language zh --output_format srt --chunk_size 5 --initial_prompt "以下是中文普通话语句。" "BV1hZ421g7xC.wav"
```

其中：
- `--model`：使用的模型
  - 可用的模型有：`tiny`, `base`, `small`, `medium`, `large`, `large-v2`, `large-v3`
  - 详见：https://github.com/openai/whisper?tab=readme-ov-file#available-models-and-languages
- `--language`：显式指定语音的语言
  - `zh` 表示中文
- `--output_format`：输出的文件格式
  - 常用的格式有：`srt`, `json`, `txt`
- `--chunk_size`：片段切分的秒数
  - 中文语音的一个较优值：`5`
- `--initial_prompt`：用于初始化的提示以约束模型输出风格

## 参考

::: tip What is the most efficient version of OpenAI Whisper? : r/MachineLearning
* https://www.reddit.com/r/MachineLearning/comments/14xxg6i/d_what_is_the_most_efficient_version_of_openai/

m-bain/whisperX: WhisperX: Automatic Speech Recognition with Word-level Timestamps (& Diarization)
* https://github.com/m-bain/whisperX
* https://github.com/m-bain/whisperX/blob/main/EXAMPLES.md

openai/whisper: Robust Speech Recognition via Large-Scale Weak Supervision
* https://github.com/openai/whisper

Simplified Chinese rather than traditional? · openai/whisper · Discussion #277
* https://github.com/openai/whisper/discussions/277
:::


## 命令行选项

<details> <summary><code>whisperx --help</code></summary>

<<< @/notes/configs/whisperx-options.txt

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/whisperx-options.txt
:::

</details>

