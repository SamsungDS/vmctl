# SPDX-License-Identifier: GPL-3.0-or-later
# Copied from https://github.com/metaspace/run-kernel
# Original from Andreas Hindborg <a.hindborg@kernel.org>

{
  description = "A system expression for vmctl";
  inputs = { nixpkgs.url = "nixpkgs/nixos-24.11"; };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [

        ({ pkgs, lib, modulesPath, ... }: {
          imports = [ (modulesPath + "/profiles/minimal.nix") ];
          options = { };
          config = {
            # Silence nix warning
            system.stateVersion = "24.11";

            # Silence missing root warning
            fileSystems."/" = lib.mkImageMediaOverride {
              fsType = "tmpfs";
              options = [ "mode=0755" ];
            };

            # Disable early boot remount
            systemd.services.systemd-remount-fs.enable = lib.mkForce false;

            # Disable Grub
            boot.loader.grub.enable = false;

            # Uncomment if kernel and initrd are unneeded and take too long
            #boot.kernel.enable = false;
            #boot.initrd.enable = false;

            networking.hostName = "";

            # Ensure DNS resolv works
            networking.networkmanager.enable = true;
            networking.resolvconf.enable = true;

            # The system is static.
            users.mutableUsers = false;

            # Empty password for root
            users.users.root.initialHashedPassword = "";

            # Log in root automatically
            services.getty.autologinUser = "root";

            # Disable the oom killer
            systemd.oomd.enable = false;

            # Disable firewall
            networking.firewall.enable = false;

            # The system cannot be rebuilt
            nix.enable = false;

            # No logical volume management
            services.lvm.enable = false;

            # Enable ssh and allow root login without password
            services.sshd.enable = true;
            services.openssh.settings.PermitRootLogin = "yes";
            services.openssh.settings.PermitEmptyPasswords = "yes";
            security.pam.services.sshd.allowNullPassword = true;

            environment.systemPackages = [ pkgs.coreutils pkgs.python3 pkgs.wget ];
          };
        })
      ];
    };
  };
}
