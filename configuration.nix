{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.allowedUDPPorts = [ 5353 ];

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  services.openssh.enable = true;

  time.timeZone = "Asia/Tokyo";

  i18n.defaultLocale = "ja_JP.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  fonts = {
    packages = with pkgs; [
      migu
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      ipafont
    ];

    fontDir.enable = true;
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif          = [ "Noto Sans CJK JP" ];
        sansSerif      = [ "Noto Sans CJK JP" ];
        monospace      = [ "Migu 1M" ];
      };
    };
  };

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  # services.xserver.displayManager.gdm.enable = true
  # services.xserver.desktopManager.gnome.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users."tomo" = {
    isNormalUser = true;
    description = "tomo";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ ];
  };

  programs.firefox.enable = true;
  programs.direnv.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    git

    # 開発・CLIツール
    neovim
    ripgrep
    fd
    fzf
    jq
    btop
    tmux
    direnv
    gh
    nodejs_22
    python3
    claude-code
    ghostty
  ];

  # 初回インストール時のリリースバージョンから変更し  換性維持のため）
  system.stateVersion = "26.05";
}
