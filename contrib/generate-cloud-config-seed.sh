#!/bin/bash

set -euo pipefail

cat <<EOF >/tmp/meta-data
instance-id: debian-1
local-hostname: debian
EOF

cat <<EOF >/tmp/user-data
#cloud-config
disable_root: false
ssh_pwauth: true
users:
  - name: vmuser
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/vmuser
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: 'vmuser'
EOF

if [[ $# -gt 0 ]]; then
  pubkey="$(<"$1")"
  cat <<EOF >>/tmp/user-data
    ssh_authorized_keys:
      - ${pubkey}
  - name: root
    ssh_authorized_keys:
      - ${pubkey}
EOF
fi

cat <<EOF >>/tmp/user-data

write_files:
- path: /etc/systemd/system/mount-shared-kernel-dir.service
  content: |
    # MIT License
    #
    # Copyright (c) 2021 Omar Sandoval
    #
    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to deal
    # in the Software without restriction, including without limitation the rights
    # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    # copies of the Software, and to permit persons to whom the Software is furnished
    # to do so, subject to the following conditions:
    #
    # The above copyright notice and this permission notice shall be included in
    # all copies or substantial portions of the Software.
    #
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
    # FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
    # OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    # WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
    # OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    #
    # Cribbed and slightly modified from a systemd unit-file created by Omar
    # Sandoval:
    #
    #    https://github.com/osandov/osandov-linux/blob/master/scripts/vm-modules-mounter.service
    #

    [Unit]
    Description=Mount shared kernel build dir
    DefaultDependencies=no
    After=systemd-remount-fs.service
    Before=local-fs-pre.target systemd-modules-load.service systemd-udevd.service kmod-static-nodes.service umount.target
    Conflicts=umount.target
    RefuseManualStop=true
    ConditionPathExists=!/lib/modules/%v/kernel

    [Install]
    WantedBy=local-fs-pre.target

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=mount -t tmpfs -o mode=755,strictatime,x-mount.mkdir,x-initrd.mount tmpfs /lib/modules/%v
    ExecStart=mount -t 9p -o trans=virtio,ro,x-mount.mkdir,x-initrd.mount kernel_dir /lib/modules/%v/build
    ExecStart=ln -s build/modules.order /lib/modules/%v/modules.order
    ExecStart=ln -s build/modules.builtin /lib/modules/%v/modules.builtin
    ExecStart=ln -s build /lib/modules/%v/kernel
    ExecStart=-depmod %v
    ExecStopPost=sh -c 'if mountpoint -q /lib/modules/%v/build; then umount -l /lib/modules/%v/build; fi'
    ExecStopPost=sh -c 'if mountpoint -q /lib/modules/%v; then umount -l /lib/modules/%v; fi'
    ExecStopPost=find /lib/modules -mindepth 1 -maxdepth 1 -type d -empty -delete
    ExecReload=-depmod %v

runcmd:
  - [ systemctl, daemon-reload ]
  - [ systemctl, enable, mount-shared-kernel-dir.service ]
EOF

cat <<EOF >>/tmp/user-data

power_state:
  mode: poweroff
  condition: True
EOF

#cloud-localds -v seed.img /tmp/cloud-config
mkisofs -output seed.img -volid cidata -joliet -rock /tmp/user-data /tmp/meta-data
rm /tmp/user-data
rm /tmp/meta-data
