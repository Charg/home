{ ... }:

{
  networking.firewall.allowedTCPPorts = [
    22

    # ac - dev containers - slot 0
    8010
    5173
    8026
    9010
    9011
    8020
    3010
    8088

    # ov - dev containers - slot 0
    8000
    8025
    9000
    9001
    8080
  ];

  # Dev containers
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 20000;
      to = 29999;
    }
  ];
}
