#!/bin/bash
# Copyright (c) 2026 [aishu](艾叔 aishuc@126.com)
# SPDX-License-Identifier: GPL-3.0-only

# 配置使用cgroups v2
sed -i 's/GRUB_CMDLINE_LINUX="/&systemd.unified_cgroup_hierarchy=1 cgroup_no_v1=all /' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-mkconfig && reboot

