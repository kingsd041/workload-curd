## 操作

该shell是通过循环的方式，根据设置的参数，通过kubectl在k8s集群上不停的创建/更新/删除 workload，支持并发。

#### 启动

```
cd workload-curd/kubectl-parallel-execution
./executer.sh
```

#### 停止

```
kill -9 `ps -ef | grep workload | awk '{print $2}'`
```

## 参数说明
- 参数1 副本最小数量
- 参数2 副本最大数量
- 参数3 副本循环增加步长
- 参数4 并发进程数

比如想修改成并发100个进程，副本数为1-3增长：

```
for i in {1..100}
do
./workload-curd.sh 1 3 1 $i &
done
```