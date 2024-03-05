# Vision Transformers

## Transformers in Vision: A Survey

二话不说先谷歌 `vision transformer survey`，肯定有人已经做了 survey：

::: tip See: Transformers in Vision: A Survey
- [abstract](https://arxiv.org/abs/2101.01169)・[ar5iv](https://ar5iv.labs.arxiv.org/html/2101.01169)・[pdf (30页)](https://arxiv.org/pdf/2101.01169.pdf)
- Salman Khan 等人，提交于 **2021-01-04**，更新于 2022-01-19.

<details open>
<summary><b>摘要</b> <f>(GLM-4 辅助翻译)</f></summary>

> Transformer 模型在自然语言任务上的惊人成果激发了计算机视觉界研究它们在计算机视觉问题中的应用。
>
> Transformer 模型的主要优点包括：
> - **能够建立输入序列元素之间的长距离依赖关系**，并且与循环网络（例如长短期记忆（LSTM））相比，**支持序列的并行处理**。
> - 与卷积网络不同，Transformer 在设计中**所需的归纳偏置较少**，并且**天然适合作为集合函数**。
> - 此外，Transformer 的直观设计允许使用类似的处理模块处理**多种模态**（例如图像、视频、文本和语音），并且**在非常大的容量网络和海量数据集上展示了出色的可扩展性**。
> 
> 这些优点促使使用 Transformer 网络在多个视觉任务上取得了令人振奋的进展。本调查旨在提供对计算机视觉领域中 Transformer 模型的全面概述。
> - 我们首先介绍 Transformer 成功背后的基本概念，即**自注意力**、**大规模预训练**和**双向编码**。
> - 然后我们涵盖了 Transformer 在视觉领域的广泛应用，包括流行的识别任务（例如图像分类、目标检测、动作识别和分割）、生成建模、多模态任务（例如视觉 - 问题回答、视觉推理和视觉定位）、视频处理（例如活动识别、视频预测）、低级视觉（例如图像超分辨率、图像增强和着色）以及 3D 分析（例如点云分类和分割）。
> - 我们比较了流行技术在架构设计和实验价值方面的各自优势和局限性。
> - 最后，我们提供了开放性研究方向的剖析和可能的未来工作的展望。
</details>
:::
