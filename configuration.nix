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
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "tomo";
  };
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

  # Moonlight (Mac等) からのリモートデスクトップ/ゲームストリーミング用ホスト
  # COSMICはwlrootsベースでないためKMSキャプチャに capSysAdmin が必要
  services.sunshine = {
    enable = true;
    capSysAdmin = true;
    openFirewall = true;
    # nixpkgsのsunshineはデフォルトでSUNSHINE_ENABLE_CUDA=falseでビルドされており、
    # NVENC自体は動いても常にVRAM->RAM->VRAMのコピーを経由するため高負荷時にFPSが落ちる。
    # cudaSupport=true でCUDA対応ビルドにし、ゼロコピーのVRAM直結パスを使わせる。
    package = pkgs.sunshine.override { cudaSupport = true; };
    settings = {
      csrf_allowed_origins = "https://nixos.local:47990";
      # HEVC Main10 / AV1 10-bit(HDR用プロファイル)を広告しない = 10bitを無効化
      hevc_mode = 2;
      av1_mode = 2;
    };
  };

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

  # xdg-user-dirs はロケール(ja_JP)に合わせて日本語フォルダ名を生成するため、
  # 英語名で固定するために user-dirs.dirs を直接書き込む
  system.activationScripts.xdgUserDirsEnglish = ''
    mkdir -p /home/tomo/{Desktop,Downloads,Templates,Public,Documents,Music,Pictures,Videos,Projects}
    chown tomo:users /home/tomo/Desktop /home/tomo/Downloads /home/tomo/Templates /home/tomo/Public /home/tomo/Documents /home/tomo/Music /home/tomo/Pictures /home/tomo/Videos /home/tomo/Projects

    mkdir -p /home/tomo/.config
    chown tomo:users /home/tomo/.config
    printf '%s\n' \
      'XDG_DESKTOP_DIR="$HOME/Desktop"' \
      'XDG_DOWNLOAD_DIR="$HOME/Downloads"' \
      'XDG_TEMPLATES_DIR="$HOME/Templates"' \
      'XDG_PUBLICSHARE_DIR="$HOME/Public"' \
      'XDG_DOCUMENTS_DIR="$HOME/Documents"' \
      'XDG_MUSIC_DIR="$HOME/Music"' \
      'XDG_PICTURES_DIR="$HOME/Pictures"' \
      'XDG_VIDEOS_DIR="$HOME/Videos"' \
      'XDG_PROJECTS_DIR="$HOME/Projects"' \
      > /home/tomo/.config/user-dirs.dirs
    chown tomo:users /home/tomo/.config/user-dirs.dirs
  '';

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
    gh
    nodejs_22
    python3
    claude-code
    ghostty
    vivaldi
  ];

  system.stateVersion = "26.05";
}
