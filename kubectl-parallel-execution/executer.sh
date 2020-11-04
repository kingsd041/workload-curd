#!/bin/bash

# 参数1 副本最小数量
# 参数2 副本最大数量
# 参数3 副本循环增加步长
# 参数4 并发进程数

for i in {1..4}
do
./workload-curd.sh 1 3 1 $i &
done
