from openai import OpenAI

base_url = "http://127.0.0.1:13333/v1"
api_key = "sk-xxxxx"

client = OpenAI(base_url=base_url, api_key=api_key)
response = client.chat.completions.create(
    model="qwen1.5-14b-chat",
    messages=[
        {
            "role": "user",
            "content": "what is your model",
        }
    ],
    stream=True,
)

for chunk in response:
    if chunk.choices[0].delta.content is not None:
        print(chunk.choices[0].delta.content, end="", flush=True)
    elif chunk.choices[0].finish_reason == "stop":
        print()
    else:
        pass