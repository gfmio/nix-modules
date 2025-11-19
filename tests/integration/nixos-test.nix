{ pkgs, self }:

pkgs.nixosTest {
  name = "nixos-integration";

  nodes.machine = { ... }: {
    imports = [
      self.nixosModules.default
    ];

    # Minimal config to test module system
    boot.loader.systemd-boot.enable = true;
    fileSystems."/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };

    users.users.test = {
      isNormalUser = true;
    };

    system.stateVersion = "24.11";
  };

  testScript = '
    machine.wait_for_unit("multi-user.target")
    machine.succeed("whoami")
  ';
}
