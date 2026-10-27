{ ... }:

{
  # Distrust root CAs we no longer want in the system trust store.
  # Names must match the comment headers in the nixpkgs cacert bundle.
  security.pki.caCertificateBlacklist = [
    # eMudhra (emSign) - compromised, Oct 2026
    "emSign Root CA - G1"
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];
}
