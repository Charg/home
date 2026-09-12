{ pkgs, ... }:

{
  # https://github.com/nix-community/nix-ld
  # Lets unpatched dynamically-linked binaries (test runners, IDE servers,
  # etc. downloaded outside of Nix) run on NixOS by giving the dynamic
  # linker a standard set of libraries to resolve against.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib # libstdc++, libgcc_s
    zlib
    glib
    openssl
  ];
}
