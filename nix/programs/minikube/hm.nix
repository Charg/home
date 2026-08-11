{
  config,
  lib,
  pkgs,
  ...
}:

{
  # minikube creates its network with an explicit subnet, so Docker's
  # default-address-pools don't govern it. Config lives in mutable JSON state
  # (~/.minikube/config/config.json), so this has to be an idempotent
  # activation step rather than home.file.
  home.activation.minikubeSubnet = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.minikube}/bin/minikube config set subnet 198.19.192.0/24 || true
  '';
}
