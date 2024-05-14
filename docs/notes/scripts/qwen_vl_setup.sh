mkdir qwen-vl
cd qwen-vl
wget https://raw.githubusercontent.com/QwenLM/Qwen-VL/master/requirements.txt
pip install -r requirements.txt

pip install optimum
pip install auto-gptq --no-build-isolation

# git clone https://githubfast.com/AutoGPTQ/AutoGPTQ.git
# cd AutoGPTQ
# pip install -v .