#!/bin/bash

set -euo pipefail

cat <<EOF >/tmp/cloud-config
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
  cat <<EOF >>/tmp/cloud-config
    ssh_authorized_keys:
      - ${pubkey}
  - name: root
    ssh_authorized_keys:
      - ${pubkey}
EOF
fi

cloud-localds -v seed.img /tmp/cloud-config
rm /tmp/cloud-config
