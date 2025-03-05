#!/bin/bash

# 公共函数脚本
m1="----------------------------------------"

# print_title 打印标题信息
# $1 要打印的标题信息
print_title() {
    echo ""
    echo "$m1"
    echo "$1"
    echo "$m1"
}

# print_blank 打印空行
print_blank() {
    echo ""
}

# print_end 打印结束标记
print_end() {
    echo "$m1"
    echo ""
}