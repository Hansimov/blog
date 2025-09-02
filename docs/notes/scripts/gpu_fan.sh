# enable gpu fan control
DISPLAY=:0 nvidia-settings -a '[gpu:0]/GPUFanControlState=1'
DISPLAY=:0 nvidia-settings -a '[gpu:1]/GPUFanControlState=1'

# set gpu fan speed
DISPLAY=:0 nvidia-settings -a '[fan:0]/GPUTargetFanSpeed=35'
DISPLAY=:0 nvidia-settings -a '[fan:1]/GPUTargetFanSpeed=35'
DISPLAY=:0 nvidia-settings -a '[fan:2]/GPUTargetFanSpeed=30'
DISPLAY=:0 nvidia-settings -a '[fan:3]/GPUTargetFanSpeed=30'