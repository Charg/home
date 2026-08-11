{
  lib,
  runCommand,
  makeWrapper,
  python3,
  iproute2,
  docker,
}:

runCommand "netcheck"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = {
      description = "Detect RFC1918/RFC2544 address collisions between the current uplink and local virtual networks";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  }
  ''
    mkdir -p $out/bin
    echo '#!${python3}/bin/python3' > $out/bin/netcheck
    cat ${./netcheck.py} >> $out/bin/netcheck
    chmod +x $out/bin/netcheck

    wrapProgram $out/bin/netcheck \
      --prefix PATH : ${
        lib.makeBinPath [
          iproute2
          docker
        ]
      }
  ''
