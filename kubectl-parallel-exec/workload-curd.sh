#!/bin/bash

# 常量
CONST_TRUE="true"
CONST_FALSE="false"
MAX_RETRY_TIME=10

OP_CREATE="create"
OP_UPDATE="update"
OP_DELETE="delete"

# 默认值
DEFAULT_RS_NUM=1
DEFAULT_SLEEP_TIME=10
DEFAULT_RANDOM_MAX=100

DEFAULT_SLEEP_UNIT="s"
DEFAULT_WORK_DIR=$(pwd)
DEFAULT_TEMPLATE_FILE="template.yaml"
DEFAULT_DEPLOYMENT_FILE="ng-deployment.yaml"
DEFAULT_NGINX_IMAGE="nginx:1.15.12"

GLOBAL_RAND=0

GLOBAL_READ_RESULT=$CONST_FALSE
GLOBAL_CREATE_RESULT=$CONST_FALSE
GLOBAL_UPDATE_RESULT=$CONST_FALSE
GLOBAL_DELETE_RESULT=$CONST_FALSE

DEFAULT_LOG_DIR=$DEFAULT_WORK_DIR/logs
DEFAULT_DEPLOYMENT_FILE_DIR=$DEFAULT_WORK_DIR/template

# 模板目录
if [ ! -d "$DEFAULT_DEPLOYMENT_FILE_DIR" ]; then
    mkdir -p $DEFAULT_DEPLOYMENT_FILE_DIR
fi

# 日志
if [ ! -d "$DEFAULT_LOG_DIR" ]; then
    mkdir -p $DEFAULT_LOG_DIR
fi
function Log() {
	echo "DEBUG:$(date '+%Y-%m-%d %H:%M:%S')-$1." >> $DEFAULT_LOG_DIR/workload-curd-$2.log
}

# 提示
function Msg() {
	echo "$1"  >> logs/workload-curd-$2.log
}

# 更新生成指定区间随机数
function RandomUpdate() {
	Log "Call method Random"
	min=$1
	max=$2
	if [ -z "$min" ];then
		min=0
	fi
	if [ -z "$max" ];then
		max=$DEFAULT_RANDOM_MAX
	fi
    GLOBAL_RAND=$(awk -v min=$min -v max=$max 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
}

# 创建
function Create() {
	Log "Call method Create" $loop
	# loop=$2
	num=$1
	path="$DEFAULT_DEPLOYMENT_FILE_DIR/$DEFAULT_DEPLOYMENT_FILE"
	if [ -z "$num" ];then
		num=$DEFAULT_RS_NUM
	fi
	cat "$DEFAULT_WORK_DIR/$DEFAULT_TEMPLATE_FILE" > $path-$loop
	if [[ "$OSTYPE" == "darwin"* ]]; then
	  sed -i '' "/^\([[:space:]]*replicas: \).*/s//\1$num/" $path-$loop
	  sed -i '' "/^\([[:space:]]*name: \).*/s//\1nginx-deployment-$loop/" $path-$loop
	  sed -i '' "/^\([[:space:]]*app: \).*/s//\1nginx-$loop/" $path-$loop
	else
	  sed -i "/^\([[:space:]]*replicas: \).*/s//\1$num/" $path-$loop
	  sed -i "/^\([[:space:]]*name: \).*/s//\1nginx-deployment-$loop/" $path-$loop
	  sed -i "/^\([[:space:]]*app: \).*/s//\1nginx-$loop/" $path-$loop
	fi
	result=$(kubectl apply -f $path-$loop)
	success="deployment.apps/nginx-deployment-$loop created"
	Log "$result" $loop
	if [ "$result" == "$success" ]; then
		GLOBAL_CREATE_RESULT=$CONST_TRUE
	else
		GLOBAL_CREATE_RESULT=$CONST_FALSE
	fi
}


# 读取(验证CUD操作结果)
function Read() {
	Log "Call method Read" $loop
	num=$1 # 应存在数量
	op=$2  # 操作
	# loop=$3 # 外部循环
	if [ -z "$num" ];then
		num="$DEFAULT_RS_NUM"
	fi
	if [ -z "$op" ];then
		op="$OP_CREATE"
	fi
	if [ "$op" == "$OP_CREATE" ]; then
		result=$( kubectl get pods -l app=nginx-$loop | grep Running |wc -l| grep -o "[^ ]\+\( \+[^ ]\+\)*" ) # Running数量
		Log "Processing:[$result/$num]" $loop
		if [ "$num" == "$result" ];then
			GLOBAL_READ_RESULT=$CONST_TRUE
		else
			GLOBAL_READ_RESULT=$CONST_FALSE
		fi
	elif [ "$op" == "$OP_DELETE" ]; then
		result=$( kubectl get pods -l app=nginx-$loop | grep nginx | wc -l | grep -o "[^ ]\+\( \+[^ ]\+\)*" ) # 总数量
		Log "Processing:[$result left]" $loop
		if [ "$num" == "$result" ];then
			GLOBAL_READ_RESULT=$CONST_TRUE
		else
			GLOBAL_READ_RESULT=$CONST_FALSE
		fi
	elif [ "$op" == "$OP_UPDATE"  ]; then
		total=$( kubectl get pods -l app=nginx-$loop | grep nginx | wc -l | grep -o "[^ ]\+\( \+[^ ]\+\)*" ) # 总数量
		running=$( kubectl get pods -l app=nginx-$loop | grep Running |wc -l| grep -o "[^ ]\+\( \+[^ ]\+\)*" ) # Running数量
		Log "Total/Running:($total/$running)" $loop
		if [ "$running" == "$total" ];then
			GLOBAL_READ_RESULT=$CONST_TRUE
		else
			GLOBAL_READ_RESULT=$CONST_FALSE
		fi
	fi
	
}

# 更新
function Update() {
	Log "Call method Update" $loop
	image=$1
	# loop=$2
	path="$DEFAULT_DEPLOYMENT_FILE_DIR/$DEFAULT_DEPLOYMENT_FILE"
	if [ -z "$imageVersion" ];then
		image=$DEFAULT_NGINX_IMAGE
	fi
	if [[ "$OSTYPE" == "darwin"* ]]; then
	  sed -i ''  "/^\([[:space:]]*image: \).*/s//\1$image/" $path-$loop
	else
	  sed -i  "/^\([[:space:]]*image: \).*/s//\1$image/" $path-$loop
	fi
	result=$(kubectl apply -f $path-$loop)
	success="deployment.apps/nginx-deployment-$loop configured"
	Log "$result" $loop
	if [ "$result" == "$success" ]; then
		GLOBAL_UPDATE_RESULT=$CONST_TRUE
	else
		GLOBAL_UPDATE_RESULT=$CONST_FALSE
	fi
}

# 删除
function Delete() {
	Log "Call method Delete" $loop
	# loop=$1
	path="$DEFAULT_DEPLOYMENT_FILE_DIR/$DEFAULT_DEPLOYMENT_FILE"
	result=$(kubectl delete -f $path-$loop)
	# NOTE 如果变更yaml，这里的信息需要更改
	success='deployment.apps "nginx-deployment-$loop" deleted'
	Log "$result" $loop
	if [ "$result" == "$success" ];then
		GLOBAL_DELETE_RESULT=$CONST_TRUE
	else
		GLOBAL_DELETE_RESULT=$CONST_FALSE
	fi
}

# 休眠
function Sleep() {
	Log "Call method Sleep" $loop
	d=$1 # 时间
	u=$DEFAULT_SLEEP_UNIT # 单位
	if [ -z "$d" ];then
		Log "Sleep duration is null,use default $DEFAULT_SLEEP_TIME"
		d=$DEFAULT_SLEEP_TIME
	fi
	Log "$d$u" $loop
	# sleep [--help] [--version] number[smhd]
	# --help : 显示辅助讯息
	# --version : 显示版本编号
	# number : 时间长度，后面可接 s、m、h 或 d
	# 其中 s 为秒，m 为 分钟，h 为小时，d 为日数
	sleep $d$u
}

# 主体逻辑
function Main() {
	start=$1
	end=$2
	step=$3
	loop=$4
	if [ -z "$start" ]; then
		start=1
	fi
	if [ -z "$end" ]; then
		end=100
	fi
	if [ -z "$step" ]; then
		step=1
	fi
	if [ -z "$loop" ]; then
		step=100
	fi
	Log "Started!" $loop
	for (( i = $start; i <= $end; i=$i+$step )); do
		Log "now $i" $loop

		# 创建逻辑
		Create "$i" "$loop"
		if [ "$GLOBAL_CREATE_RESULT" == "$CONST_TRUE" ]; then
			Msg "Create call success." $loop
		fi
		while [ "$GLOBAL_READ_RESULT" == "$CONST_FALSE" ]; do
			Msg "Creating." $loop
			Sleep "$DEFAULT_SLEEP_TIME"
			Read "$i" "$OP_CREATE" "$loop"
		done
		Msg "All of $i is created." $loop
		GLOBAL_READ_RESULT=$CONST_FALSE

		# 更新逻辑
		Update "$DEFAULT_NGINX_IMAGE" "$loop"
		if [ "$GLOBAL_UPDATE_RESULT" == "$CONST_TRUE" ];then
			Msg "Update call success." $loop
		fi
		while [ "$GLOBAL_READ_RESULT" == "$CONST_FALSE" ]; do
			Msg "Updating." $loop
			Sleep "$DEFAULT_SLEEP_TIME"
			Read "$i" "$OP_UPDATE" "$loop"
		done
		Msg "All of $i is updated." $loop
		GLOBAL_READ_RESULT=$CONST_FALSE

		# 删除逻辑
		Delete $loop
		if [ "$GLOBAL_DELETE_RESULT" == "$CONST_TRUE" ];then
			Msg "Delete call success." $loop
		fi
		while [ "$GLOBAL_READ_RESULT" == "$CONST_FALSE" ]; do
			Msg "Deleting." $loop
			Sleep "$DEFAULT_SLEEP_TIME"
			Read 0 "$OP_DELETE"
		done
		Msg "All of $i is deleted." $loop
		GLOBAL_READ_RESULT=$CONST_FALSE

	done
	Log "---Ended!---" $loop
}


# Call Main 
# 参数1 副本最小数量
# 参数2 副本最大数量
# 参数3 副本循环增加步长
while true
do
    Main $1 $2 $3 $4
done
