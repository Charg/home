{ ... }:

# Standalone servers outside the k3s cluster: just an admin account.
{
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../common/keys/home.pub)
    ];
  };
}
