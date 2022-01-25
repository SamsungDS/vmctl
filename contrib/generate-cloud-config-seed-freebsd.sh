#!/bin/bash

set -euo pipefail

cat <<EOF >/tmp/cloud-config
#cloud-config
disable_root: false

users:
  - name: vmuser
    sudo: ALL=(ALL) NOPASSWD:ALL
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

cat <<EOF >>/tmp/cloud-config
write_files:
- path: /etc/ssh/sshd_config
  content: |
    PermitRootLogin yes
    AuthorizedKeysFile .ssh/authorized_keys
    Subsystem sftp  /usr/libexec/sftp-server
EOF

cat <<EOF >>/tmp/cloud-config

power_state:
  mode: poweroff
  condition: True
EOF

cloud-localds -v seed.img /tmp/cloud-config
rm /tmp/cloud-config
