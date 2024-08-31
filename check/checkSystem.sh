#!/bin/bash
# 获取服务器基本信息
hostname=$(hostname)
ip_address=$(hostname -I | awk '{print $1}')
os=$(lsb_release -ds)
kernel=$(uname -r)
uptime=$(uptime -p)
# 监控循环
while true; do
    # 获取CPU信息
    cpu_model=$(cat /proc/cpuinfo | grep "model name" | head -n1 | awk -F': ' '{print $2}')
    cpu_cores=$(cat /proc/cpuinfo | grep "model name" | wc -l)
    # 获取内存信息（加入单位）
    memory_total=$(free -h | awk 'NR==2{print $2}')
    memory_used=$(free -h | awk 'NR==2{print $3}')
    memory_free=$(free -h | awk 'NR==2{print $4}')
    memory_available=$(free -h | awk 'NR==2{print $7}')
    # 获取磁盘使用情况
    disk_total=$(df -h --output=size / | awk 'NR==2{print $1}')
    disk_used=$(df -h --output=used / | awk 'NR==2{print $1}')
    disk_free=$(df -h --output=avail / | awk 'NR==2{print $1}')
    # 使用 top 命令获取 CPU 使用率
    cpu_usage=$(top -b -n 1 | grep "%Cpu(s):" | awk '{printf "%.2f%%", 100-$8}')
    # 输出监控信息
    clear
    echo "服务器信息："
    echo "主机名：$hostname"
    echo "IP地址：$ip_address"
    echo "操作系统：$os"
    echo "内核版本：$kernel"
    echo "运行时间：$uptime"
    echo "--------------------------------------"
    echo "CPU信息："
    echo "型号：$cpu_model"
    echo "核心数：$cpu_cores"
    echo "CPU使用率：$cpu_usage"
    echo "--------------------------------------"
    echo "内存信息："
    echo "总量：$memory_total"
    echo "已使用：$memory_used"
    echo "可用：$memory_available"
    echo "--------------------------------------"
    echo "磁盘信息："
    echo "总量：$disk_total"
    echo "已使用：$disk_used"
    echo "可用：$disk_free"

    # 每 3 秒刷新一次
    sleep 3
done
