#!/bin/bash

# 监控目录和文件名
HOSTNAME=$(hostname)
echo $HOSTNAME
HOSTIP=$(hostname -I)
dir_path="/www/wwwlogs/oms_admin"

filelists=`ls -ltrh $dir_path | head -n 3 | awk '{print $NF}'`

# webhook 地址
#webhook_url="https://oapi.dingtalk.com/robot/send?access_token=XXXX"
webhook_url="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=1f61ca30-866b-462b-901b-42d488a1a4f3"
set_payload_file(){
cat  > /www/payload_result.json << \EOF
{       
    "msgtype": "markdown",
    "markdown": {
        "content":"
##### 服务器<font color=#67C23A>hostname</font>(<font color=#FF0000>hostip</font> )上MySQL binlog日志文件清理通知 \n
>  ##### <font color=#67C23A> 【文件路径】</font> :<font color=#FF0000> template1 </font> \n
>  ##### <font color=#67C23A> 【文件大小】</font> :<font color=#FF0000> template2</font> \n
>  ##### <font color=#67C23A>  此文件已经完成清理，请知悉</font> \n
"
}
}        
EOF
}


delete_file(){  
cd $dir_path
for file in $filelists; do
    if [[ -f "$file" ]]; then
      # 获取文件大小（单位：字节）
      file_size=$(stat -c "%s" "$file")
      file_size_mb=$((file_size/(1024*1024)))
      rm -f $file
      # 发送告警到 webhook 机器人
        message1="$dir_path/${file}"
        message2="${file_size_mb} MB"
        set_payload_file
        sed -i "s^template1^$message1^g" /www/payload_result.json
        sed -i "s^template2^$message2^g" /www/payload_result.json
        sed -i "s^hostname^$HOSTNAME^g" /www/payload_result.json
        sed -i "s^hostip^$HOSTIP^g"   /www/payload_result.json
        response=$(curl -sS -H "Content-Type: application/json" -X POST -d @/www/payload_result.json "${webhook_url}")
        if [ $? -eq 0 ]; then
            echo "Alert sent successfully"
        else
            echo "Failed to send alert: ${response}"
        fi
      fi
done
}
delete_file
