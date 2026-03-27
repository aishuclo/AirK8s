#!/bin/bash
# Copyright (c) 2026 [aishu](艾叔 aishuc@126.com)
# SPDX-License-Identifier: GPL-3.0-only

OLD_IP="192.168.228.128"
NEW_IP="192.168.229.128"

# 获取所有本地镜像，格式为 "repository:tag"
docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
    # 如果镜像名包含旧IP，则处理
    if [[ "$image" == *"$OLD_IP"* ]]; then
        # 替换旧IP为新IP
        new_image="${image//$OLD_IP/$NEW_IP}"
        echo "Tagging $image -> $new_image"
        docker tag $image $new_image
	docker rmi $image
    fi
done
