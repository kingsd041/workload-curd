## 说明

该shell是通过循环的方式，根据设置的参数，通过kubectl在k8s集群上不停的创建workload，只支持单进程。

## 操作

#### 启动
```
cd workload-curd
./workload-curd.sh
```
#### 停止

```
control + c
```

## 参数说明

- 参数1 副本最小数量
- 参数2 副本最大数量
- 参数3 副本循环增加步长

比如，想修改成从1个副本开始，步长为1，最大75个副本：
```
while true
do
    let numb+=1
    echo "### -- $numb" >> count.txt
    echo "Begin: `date` -- $numb" >> count.txt
    Main 1 75 1
    echo "End: `date`  -- $numb" >> count.txt
done
```
