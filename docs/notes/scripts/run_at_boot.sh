echo "RUN: Xvfb"
Xvfb -ac :99 -screen 0 1280x1024x16 &

echo "RUN: webu.ipv6.route"
echo $SUDOPASS | sudo -S env "PATH=$PATH" python -m webu.ipv6.route

echo "RUN: ulimit -n 1048576"
ulimit -n 1048576

echo "RUN: set GPU power limit, and fans full speed"
gpu_pow -pm a:1 && gpu_pow -pl "a:160"
gpu_fan -cs a:1 && gpu_fan -fs "a:100"
