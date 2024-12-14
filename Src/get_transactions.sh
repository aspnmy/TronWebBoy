#!/bin/bash

# 查找指定地址交易记录
get_tron_transactions_info() {
    local contractAddress="$1"  

    url="https://api.shasta.trongrid.io/v1/accounts/$contractAddress/transactions"

    response=$(curl -X GET -H 'accept: application/json' -H "TRON-PRO-API-KEY: ${TRON_PRO_API_KEY}" "$url")
    if [ $? -eq 0 ]
    then
        echo "$response"
    else
        echo "Error: Failed to retrieve transaction information."
    fi


}