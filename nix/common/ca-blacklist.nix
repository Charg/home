{ ... }:

{
  # Distrust root CAs we no longer want in the system trust store.
  # Names must match the comment headers in the nixpkgs cacert bundle.
  security.pki.caCertificateBlacklist = [
    # eMudhra (emSign) - compromised, Oct 2026. G3/C1/C3 were dropped
    # upstream in nss 3.131.1; listing absent certs fails the cacert build.
    "emSign Root CA - G1"
    # Not compromised itself, but it cross-signs eMudhra certs, so it is
    # an alternate trust path to them. Mozilla/Chrome/Ubuntu dropped it too.
    "Comodo AAA Services root"
  ];
}
