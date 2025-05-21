# :wrench: vmctl

[![Build Status](https://github.com/OpenMPDK/vmctl/workflows/ci/badge.svg)](https://github.com/OpenMPDK/vmctl/actions)

QEMU NVMe Testing Galore!

`vmctl` is a tool to rapidly getting preconfigured QEMU virtual machines up and
running.


## Getting Started (Manual Mode)

1. Clone the `vmctl` repository.

2. Bootstrap a config directory with the following command:

       $ ./vmctl env --confdir $HOME/vms --verbose --bootstrap

   **Note** This will:
    * Ensure that you have `ssh` and `socat` installed
    * Create a configuration directory in $HOME/vms
    * Ensure you have a base `*-base.conf`
    * Ensure you have `common.conf` (to share common vars like
      `QEMU_SYSTEM_BINARY`)

3. There are two ways of executing `vmctl`:
    1. Symlink in your path to always have it available "natively"

        $ ln -s /path/to/vmctl/vmctl $HOME/bin/vmctl
        $ vmctl --help
        $ vmctl -c CONFIG <command>

    2. Activate `vmctl` with `env` for your current shell

        $ ./vmctl env --confdir $HOME/vms
        $ vmctl --help
        $ vmctl -c CONFIG <command>

4. Prepare a boot image. The base configruation `*-base.conf` will look for a
   base image in `img/base.qcow2`. You can use [archbase][archbase] to build a
   lean Arch Linux base image or grab a QCOW2-based [Ubuntu cloud
   image][ubuntu-cloud-image] if that's your vice.

   In the case of a standard "cloud image", you probably want to resize it
   since it is usually shrunk to be as small as possible by default.

       $ qemu-img resize img/base.qcow2 8G

   **Note** The example `nvme.conf` will define `GUEST_BOOT="img/nvme.qcow2"`.
   You do not need to provide that image - if it is not there `$GUEST_BOOT`
   will be a differential image backed by `img/base.qcow2`. So, if you ever
   need to reset to the "base" state, just remove the `img/nvme.qcow2` image.

5. Start from an example and edit it as you see fit.

       $ edit $HOME/vms/nvme.conf

[archbase]: https://github.com/OpenMPDK/archbase
[ubuntu-cloud-image]: https://cloud-images.ubuntu.com

## Virtual Machine Configurations

In essence, a virtual machine configuration must provide the `QEMU_PARAMS`
array and do any required initialization of VM images. Typically, a base
configuration `*-base.conf` in combination with the `qemu_` helpers will "just
work".


## Running Virtual Machines

To launch a VM, use `vmctl -c CONFIG run`. This will launch the VM specified in
the `CONFIG` config file in interactive mode such that the VM serial output is
sent to standard out. The QEMU monitor is multiplexed to standard out, so you
can access it by issuing `Ctrl-a c`.

### cloud-init

If your chosen base image is meant to be configured through [cloud-init][cloud-init],
you can use the included cloud-config helper script to generate a basic
cloud-init seed image:

    $ ./contrib/generate-cloud-config-seed.sh ~/.ssh/id_rsa.pub
    
If the image is running freebsd, use the script with `-freebsd` suffix:
    
    $ ./contrib/generate-cloud-config-seed-freebsd.sh ~/.ssh/id_rsa.pub

This will generate a simple cloud-init seed image that will set up the image
with a default `vmuser` account that can be logged into using the given public
key. Place the output image (`seed.img`) in `img/` and pass the `--cloud-init`
(short: `'-c'`) option to `vmctl run` to initialize the image on first boot:

    $ vmctl -c CONFIG run -c

cloud-init will automatically power off the virtual machine when it has been
configured.

NOTE: For the cloud-config helper script to work `cloud-utils` is required.

[cloud-init]: https://cloudinit.readthedocs.io/en/latest/


### SSH, Serial console and QEMU monitor

By default, `vmctl` will launch the guest such that the serial console and the
QEMU monitor is multiplexed to standard out. This means that you will see the
serial console output directly on the screen.

To connect to the guest with ssh, do

    $ vmctl -c CONFIG ssh

If you start the guest in the background (`-b`, `--background`), you can access
the console and monitor using

    $ vmctl -c CONFIG console
    $ vmctl -c CONFIG monitor

### Tracing

The `--trace` (short: `-t`) option can be used to enable tracing inside QEMU.
The trace events will be sent to the `log/${VMNAME}/qemu.log` file (along with
any other messages written to standard error by the QEMU process). For example,
to enable all trace events for the NVMe device, but disabling anything related
to IRQs, use

    vmctl -c CONFIG run -t 'pci_nvme,-pci_nvme_irq'

`vmctl` inserts an implicit `*`-suffix such that all traces with the given
prefix is traced.

### Custom kernel

Finally, the `--kernel-dir` (short: `-k`) can be used to point to a custom
Linux kernel to boot directly. This directory will be made available to the VM
as a p9 virtual file system with mount tag `kernel_dir`. If supported by the VM
being booted, this allows it to use kernel modules from that directory. The
image built by `archbase` has support for this built-in and the
`contrib/generate-cloud-config-seed.sh` script will generate a cloud-init seed
that configures the image to support this. In non-cloud-init settings, see
`contrib/systemd` for a systemd service that should be usable on most
distributions.


## License

`vmctl` is licensed under the GNU General Public License v3.0 or later.
