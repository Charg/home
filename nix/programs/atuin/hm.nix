{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      search_mode = "fuzzy";
      filter_mode = "global";
      style = "compact";
      inline_height = 20;
      show_preview = true;
      enter_accept = false;
      secrets_filter = true;
      update_check = false;
      auto_sync = false;
      sync_address = "http://127.0.0.1:9";
    };
  };
}
