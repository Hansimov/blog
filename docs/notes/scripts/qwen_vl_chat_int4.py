from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

torch.manual_seed(1234)

model_name = "Qwen/Qwen-VL-Chat-Int4"
tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True)
model = AutoModelForCausalLM.from_pretrained(
    model_name, device_map="auto", trust_remote_code=True
).eval()

# 1st dialogue turn
messages = [
    {
        "image": "https://qianwen-res.oss-cn-beijing.aliyuncs.com/Qwen-VL/assets/demo.jpeg",
    },
    {
        "text": "Describe in detail this image in Chinese:",
    },
]
query = tokenizer.from_list_format(messages)
response, history = model.chat(tokenizer, query=query, history=None)
print(response)


# # 2nd dialogue turn
# response, history = model.chat(tokenizer, '输出"击掌"的检测框', history=history)
# print(response)
# # <ref>击掌</ref><box>(517,508),(589,611)</box>
# image = tokenizer.draw_bbox_on_latest_picture(response, history)
# if image:
#     image.save("1.jpg")
# else:
#     print("no box")
