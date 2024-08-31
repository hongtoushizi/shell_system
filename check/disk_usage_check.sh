#!/bin/bash

# 设置警告阈值
THRESHOLD=10

#
CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
# 获取主机名和IP
HOSTNAME=$(hostname)
IP=$(hostname -I)

# 筛选需要检查的磁盘并进行检查
df -lPh | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | while read output;
do
  used=$(echo $output | awk '{print $1}' | cut -d'%' -f1)
  partition=$(echo $output | awk '{print $2}')

  if (( used >= THRESHOLD )); then
    # 构建payload
    PAYLOAD=$(cat <<-EOF
{       
"msgtype": "markdown",
"markdown": {
  "content":"
##### Linux服务器磁盘空间告警 \n
>  ##### <font color=#67C23A> 【服务器: </font> <font color=#FF0000> $HOSTNAME 的磁盘空间超过阀值</font> :<font color=#FF0000> $THRESHOLD%  </font> \n
>  ##### <font color=#67C23A> 【服务器IP】</font> :<font color=#FF0000> $IP </font> \n
>  ##### <font color=#67C23A> 【告警时间】</font> :<font color=#FF0000> $CURRENT_TIME </font> \n
>  ##### <font color=#67C23A> 【磁盘空间占用高的分区】</font>:<font color=#FF0000> $partition </font> 已使用 <font color=#FF0000>$used%</font> \n
>  ##### <font color=#67C23A>  该分区具体df -PTh信息如下: </font> \n
>  ##### <font color=#FF0000>  $(df -lPTh | head -n 1) </font> \n
>  ##### <font color=#FF0000>  $(df -lPTh| grep $partition) </font> \n
"
}
}
EOF
    )

    # 发送告警 (自行替换钉钉Webhook机器人的URL)
    curl -H "Content-Type: application/json" -X POST -d "$PAYLOAD"  https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=1f61ca30-866b-462b-901b-42d488a1a4f3
    echo $PAYLOAD
  fi
done

