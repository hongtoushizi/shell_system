#!/bin/bash
# 检查是否输入了端口号
if [[ $# -eq 0 ]]; then
    echo '请指定要杀死的端口号'
    exit 1
fi
# 循环遍历输入的每个端口号
for PORT in "$@"; do
    # 检查端口是否被占用
    PID=$(lsof -i :$PORT | awk 'NR==2{print $2}')
    if [[ ! -n $PID ]]; then
        echo "找不到端口 $PORT"
    else
        # 杀死进程
        echo "杀死端口 $PORT 对应的进程 $PID"
        kill -9 $PID
    fi
done
