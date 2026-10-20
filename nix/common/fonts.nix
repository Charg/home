{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    inter
    jetbrains-mono
    nerd-fonts.symbols-only # icon glyphs as a fallback for any font (eza, starship)
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  # Without these, fontconfig resolves the generic families to DejaVu.
  fonts.fontconfig.defaultFonts = {
    sansSerif = [
      "Inter"
      "Noto Sans"
    ];
    serif = [ "Noto Serif" ];
    monospace = [
      "JetBrains Mono"
      "Symbols Nerd Font Mono"
    ];
    emoji = [ "Noto Color Emoji" ];
  };
}
