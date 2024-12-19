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

LogsPATH="${CURRENT_DIR}/logs"
WebLogsPATH="${CURRENT_DIR}/web_logs"
JSON_OUTPATH="${WebLogsPATH}/content.json"

# 确保日志目录存在
mkdir -p "$LogsPATH"
mkdir -p "$WebLogsPATH"

function log() {
    message="[Aspnmy Log]: $1"
    case "$1" in
        *"失败"*|*"错误"*|*"请使用 root 或 sudo 权限运行此脚本"*|*"无法获取响应"*|*"请求失败"*|*"没有数据"*|*"发现null值，函数中止。")
            echo -e "${RED}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/TrxMan.log"
            ;;
        *"成功"*|*"正常退出函数")
            echo -e "${GREEN}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/TrxMan.log"
            ;;
        *"忽略"*|*"跳过"*|*"提前退出函数")
            echo -e "${YELLOW}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/TrxMan.log"
            ;;
        *)
            echo -e "${BLUE}${message}${NC}" 2>&1 | tee -a "${LogsPATH}/TrxMan.log"
            ;;
    esac
}

# 正式输出前合并满足要求的文件
# 正式输出前合并满足要求的文件
function merge_json() {
    local json_a="$1"
    local json_b="$2"
    local json_c="$3"

    # 提取 wallet_address
    local addr_a=$(echo "$json_a" | jq -r '.wallet_address')
    local addr_b=$(echo "$json_b" | jq -r '.wallet_address')
    local addr_c=$(echo "$json_c" | jq -r '.wallet_address')

    # 检查 wallet_address 是否一致
    if [ "$addr_a" == "$addr_b" ] && [ "$addr_b" == "$addr_c" ]; then
        # 三个 wallet_address 一致，合并所有 data
        local common_addr="$addr_a"
        local data_a=$(echo "$json_a" | jq '.data')
        local data_b=$(echo "$json_b" | jq '.data')
        local data_c=$(echo "$json_c" | jq '.data')

        # 合并 data 字段
        local merged_json=$(jq -n \
            --arg addr "$common_addr" \
            --argjson data1 "$data_a" \
            --argjson data2 "$data_b" \
            --argjson data3 "$data_c" \
            '{wallet_address: $addr, data: [$data1, $data2, $data3]}')
    elif [ "$addr_a" == "$addr_b" ]; then
        # 两个 wallet_address 一致，合并这两个 data
        local common_addr="$addr_a"
        local data_a=$(echo "$json_a" | jq '.data')
        local data_b=$(echo "$json_b" | jq '.data')

        # 合并 data 字段
        local merged_json=$(jq -n \
            --arg addr "$common_addr" \
            --argjson data1 "$data_a" \
            --argjson data2 "$data_b" \
            '{wallet_address: $addr, data: [$data1, $data2]}')
    elif [ "$addr_a" == "$addr_c" ]; then
        # 两个 wallet_address 一致，合并这两个 data
        local common_addr="$addr_a"
        local data_a=$(echo "$json_a" | jq '.data')
        local data_c=$(echo "$json_c" | jq '.data')

        # 合并 data 字段
        local merged_json=$(jq -n \
            --arg addr "$common_addr" \
            --argjson data1 "$data_a" \
            --argjson data3 "$data_c" \
            '{wallet_address: $addr, data: [$data1, $data3]}')
    elif [ "$addr_b" == "$addr_c" ]; then
        # 两个 wallet_address 一致，合并这两个 data
        local common_addr="$addr_b"
        local data_b=$(echo "$json_b" | jq '.data')
        local data_c=$(echo "$json_c" | jq '.data')

        # 合并 data 字段
        local merged_json=$(jq -n \
            --arg addr "$common_addr" \
            --argjson data2 "$data_b" \
            --argjson data3 "$data_c" \
            '{wallet_address: $addr, data: [$data2, $data3]}')
    else
        # 三个 wallet_address 都不一致，输出所有 JSON
        log "没有足够的 wallet_address 一致，无法合并。"
        echo "$json_a" | tee -a "$JSON_OUTPATH"
        echo "$json_b" | tee -a "$JSON_OUTPATH"
        echo "$json_c" | tee -a "$JSON_OUTPATH"
        return 1
    fi

    # 输出合并后的 JSON 到文件
    echo "$merged_json" | tee -a "$JSON_OUTPATH"
}


# 正式输出前构造结构
function format_results() {
    local walletaddress=$1
    local data=$2
    # 使用 sed 删除包含 [Aspnmy Log]: 的行
    local filtered_data=$(echo "$data" | sed '/\[Aspnmy Log\]:/d')

    # # 构造 JSON 格式的输出
    # local json_output=$(jq -n \
    #     --arg ct "$walletaddress" \
    #     --arg lot "$filtered_data" \
    #     '{ "wallet_address": $ct, "data": $lot }')
        # 构造 JSON 格式的输出
    local json_output="{\"wallet_address\": \"$walletaddress\", \"data\": "$filtered_data" }"
    echo "$json_output"
}

# 定义格式化 JSON 的函数
function format_json() {
    local json_str="$1"
    echo "$json_str" | jq .
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
        log "没有 USDT 余额。"
        local Trc20Balance=0
    else
        local Trc20Balance=$(echo "scale=6; $tokenBalance / 1000000" | bc)
    fi
    # 获取 balance
    local balance=$(echo "$json_data" | jq -r '.data[0].balance')
    if [ -z "$balance" ] || [ "$balance" == "null" ]; then
        log "没有 TRX 余额。"
        local trxBalance=0
    else
        local trxBalance=$(echo "scale=6; $balance / 1000000" | bc)
    fi
    log "TRC20合约地址: $contractAddress"
    log "USDT: $Trc20Balance"
    log "TRX 余额: $trxBalance"
    # 构造 JSON 格式的输出
    local json_output=$(jq -n \
        --arg ca "$contractAddress" \
        --arg tb "$Trc20Balance" \
        --arg trx "$trxBalance" \
        '{ "TRC20合约地址": $ca, "USDT余额": $tb, "TRX余额": $trx }')
    echo "$json_output"
}

# 函数：解析 owner_permission 数组中的权重数据(多签)
# 函数：解析特定的地址和权重
parse_specific_values() {
    local json_data=$1

    # 获取键的数量
    local num_keys=$(echo "$json_data" | jq length)

    # 初始化一个空的 JSON 数组
    local addresses_weights_json="[]"

    # 遍历所有的键
    for ((i=0; i<num_keys; i++)); do
        # 获取地址和权重
        local address=$(echo "$json_data" | jq -r ".data[0].owner_permission.keys[$i].address")
        local weight=$(echo "$json_data" | jq -r ".data[0].owner_permission.keys[$i].weight")

        # 检查地址或权重是否为null
        if [[ "$address" == "null" || "$weight" == "null" ]]; then
            continue  # 跳过无效值
        fi

        # 构建单个地址和权重的 JSON 对象
        local entry=$(jq -n \
            --arg addr "$address" \
            --argjson wt "$weight" \
            '{ "地址": $addr, "权重": $wt }')
        # 将单个地址和权重的 JSON 对象添加到数组中
        addresses_weights_json=$(echo "$addresses_weights_json" | jq --argjson entry "$entry" '. + [$entry]')
    done

    # 输出包含所有地址和权重的 JSON 数组
    echo "$addresses_weights_json"
}

# 函数：解析时间和操作时间
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

    # 构建 JSON 对象
   
    local json_output=$(jq -n \
    --arg ct "$formatted_create_time UTC" \
    --arg lot "$formatted_latest_opration_time UTC" \
    '{ "创建时间": $ct, "最新操作时间": $lot }')
    echo "$json_output"
}
#函数：获取波场地址余额
get_balance_by_address() {
    local address="$1"
    local api_url="https://api.trongrid.io/v1/accounts/${address}"
    local TRON_PRO_API_KEY="Api-key"
    # 发送 HTTP GET 请求
    local response=$(curl -s -H "Content-Type: application/json" -H "TRON-PRO-API-KEY: ${TRON_PRO_API_KEY}" "$api_url")

    # 检查响应是否为空
    if [ -z "$response" ]; then
        log "无法获取响应。"
        return 1
    fi

    # 使用 jq 解析 JSON 响应
    local success=$(echo "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        log "请求失败。"
        return 1
    fi

    local data=$(echo "$response" | jq -r '.data')
    if [ -z "$data" ] || [ "$data" == "null" ]; then
        log "没有数据。"
        return 1
    fi

    echo "$response"
    }
    main() {
    if [ $# -eq 0 ]; then
    log "请提供一个波场地址作为参数。"
    exit 1
    fi
    walletaddress=$1
    log "正在获取地址 $walletaddress 的余额信息..."
    res=$(get_balance_by_address "$walletaddress")
    if [ $? -ne 0 ]; then
        log "由于网络问题，无法解析链接 'https://api.trongrid.io/v1/accounts/${walletaddress}'。请检查网络连接和链接的合法性，并适当重试。如果不需要该链接的解析，也可以正常回答用户的问题。"
        exit 1
    fi
    trc20_balance_json=$(parse_trc20_and_balance "$res")
    specific_values_json=$(parse_specific_values "$res")
    times_json=$(parse_and_address_format_times "$res")
    
    #format_json
    a=$(format_results "$walletaddress" "$trc20_balance_json")

    b=$(format_results "$walletaddress" "$specific_values_json")
   
    c=$(format_results "$walletaddress" "$times_json")
    data=$(merge_json "$a" "$b" "$c")

    echo $data
}
main "$@"