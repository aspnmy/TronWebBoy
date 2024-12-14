#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CURRENT_DIR=$(
    cd "$(dirname "$0")" || exit
    pwd
)

WebLogsPATH="${CURRENT_DIR}/web_logs"
JSON_OUTPATH="${WebLogsPATH}/content.json"

function log() {
    message="[Aspnmy Log]: $1"
    case "$1" in
        *"失败"*|*"错误"*|*"请使用 root 或 sudo 权限运行此脚本"*)
            echo -e "${RED}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/TrxMan.log"
            ;;
        *"成功"*)
            echo -e "${GREEN}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/TrxMan.log"
            ;;
        *"忽略"*|*"跳过"*)
            echo -e "${YELLOW}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/TrxMan.log"
            ;;
        *)
            echo -e "${BLUE}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/TrxMan.log"
            ;;
    esac
}
function output_results() {
    local data=$1

    local json_output="{\"data\:$data\"}"
    echo "$json_output" | tee -a "$JSON_OUTPATH"
}



# 函数：解析 trc20 数组中的合约地址和余额，以及 balance
parse_trc20_and_balance() {
    local json_data=$1

    # 使用 jq 解析 trc20 数组中的第一个对象
    local trc20_obj=$(echo "$json_data" | jq -r '.data[0].trc20[0]')
    
    # 获取合约地址（键）
    local contractAddress=$(echo "$trc20_obj" | jq -r 'keys[0]')
    
    # 获取合约余额（值）
    local tokenBalance=$(echo "$trc20_obj" | jq -r '.["'"$contractAddress"'"]')
    if [ -z "$tokenBalance" ] || [ "$tokenBalance" == "null" ]; then
        echo "没有 USDT 余额。"
        local Trc20Balance=0
    else
        local Trc20Balance=$(echo "scale=6; $tokenBalance / 1000000" | bc)
    fi
    # 获取 balance
    local balance=$(echo "$json_data" | jq -r '.data[0].balance')
    if [ -z "$balance" ] || [ "$balance" == "null" ]; then
        echo "没有 TRX 余额。"
        local trxBalance=0
    else
        local trxBalance=$(echo "scale=6; $balance / 1000000" | bc)
    fi
    echo "TRC20合约地址: $contractAddress"
    echo "USDT: $Trc20Balance"
    echo "TRX 余额: $trxBalance"
    # 构造 JSON 格式的输出
    # local json_output="{\"TRC20合约地址\": \"$contractAddress\", \"USDT余额\": \"$Trc20Balance\", \"TRX余额\": \"$trxBalance\"}"
    
    # # 输出 JSON
    # echo "$json_output"
}

# 函数：解析 owner_permission 数组中的权重数据(多签)
# 函数：解析特定的地址和权重
parse_specific_values() {
    local json_data=$1

    # 获取键的数量
    local num_keys=$(echo "$json_data" | jq length)

    # 遍历所有的键
    for ((i=0; i<num_keys; i++)); do
        # 获取地址和权重
        local address=$(echo "$json_data" | jq -r ".data[0].owner_permission.keys[$i].address")
        local weight=$(echo "$json_data" | jq -r ".data[0].owner_permission.keys[$i].weight")

        # 检查地址或权重是否为null
        if [[ "$address" == "null" || "$weight" == "null" ]]; then
            #echo "发现null值，函数中止。"
            return 1  # 提前退出函数
        fi

        echo "地址 $((i+1)): $address"
        echo "权重 $((i+1)): $weight"
    done

    return 0  # 正常退出函数
}

parse_and_address_format_times() {
    local json_data=$1

    # 获取 create_time 并转换为秒
    local create_time_ms=$(echo "$json_data" | jq -r '.data[0].create_time')
    local create_time_s=$((create_time_ms / 1000))

    # 获取 latest_opration_time 并转换为秒
    local latest_opration_time_ms=$(echo "$json_data" | jq -r '.data[0].latest_opration_time')
    local latest_opration_time_s=$((latest_opration_time_ms / 1000))

    # 格式化时间戳
    local formatted_create_time=$(date -u -d @"$create_time_s" +"%Y-%m-%d %H:%M:%S")
    local formatted_latest_opration_time=$(date -u -d @"$latest_opration_time_s" +"%Y-%m-%d %H:%M:%S")

    echo "创建时间: $formatted_create_time UTC"
    echo "最新操作时间: $formatted_latest_opration_time UTC"
}

# 函数：获取波场地址余额
get_balance_by_address() {
    local address="$1"
    local api_url="https://api.trongrid.io/v1/accounts/${address}"
    local TRON_PRO_API_KEY="74585769-5708-40c8-9db0-e4f5fd8c570d"
    
    # 发送 HTTP GET 请求
    local response=$(curl -s -H "Content-Type: application/json" -H "TRON-PRO-API-KEY: ${TRON_PRO_API_KEY}" "$api_url")

    # 检查响应是否为空
    if [ -z "$response" ]; then
        echo "无法获取响应。"
        return
    fi

    # 使用 jq 解析 JSON 响应
    local success=$(echo "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        echo "请求失败。"
        return
    fi

    local data=$(echo "$response" | jq -r '.data')
    if [ -z "$data" ] || [ "$data" == "null" ]; then
        echo "没有数据。"
        return
    fi
    return $response

    # # 构造 JSON 格式的输出
    # local json_output="{\"TRC20地址与余额\": \"$contractAddress\", \"USDT余额\": \"$Trc20Balance\", \"TRX余额\": \"$trxBalance\"}"
    
    # # # 输出 JSON
    # # echo "$json_output"


}

main(){
    walletaddress=$1
    res=get_balance_by_address "$walletaddress"
    parse_trc20_and_balance "$res"
    parse_specific_values "$res"
    parse_and_address_format_times "$res"

}


main

