#!/bin/bash

# JSON文件路径
JSON_FILE="data/up_jsonfile.json"

# 检查JSON文件是否存在
if [ ! -f "$JSON_FILE" ]; then
    echo "JSON file not found!"
    exit 1
fi

# 使用jq解析JSON文件中的address字段，并分割成数组
addresses=$(jq -r '.address | split(",")[]' "$JSON_FILE")

# 循环遍历地址列表
for address in $addresses; do
    # 对每个地址运行trx_base_json.sh脚本
    ./trx_base_json.sh "$address"
done

echo "All addresses processed."