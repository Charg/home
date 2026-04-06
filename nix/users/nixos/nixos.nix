{ pkgs, inputs, ... }:

{
  users.users.nixos = {
    isNormalUser = true;
    hashedPassword = "$6$LsYSVIubO9ddl8lB$zGowqj8q0YLJZpGpKPjCf5wIDE6AnoOvOdPZIpiP213Dus0niljEDMQz0TJX3COGc70q2OHnZ.nut824iNiRo.";
  };

  services.k3s = {
    enable = true;
    role = "server";
    disable = [
      "traefik"
      "servicelb"
      "metrics-server"
    ];
    extraFlags = "--disable=traefik --disable=servicelb";
  };
}
