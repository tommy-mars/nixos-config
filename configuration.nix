{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ─────────────────────────────────
  # 1. システム基本設定（ブート / カーネル）
  # ─────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ─────────────────────────────────
  # 2. ネットワーク・ホスト名・ファイアウォール
  # ─────────────────────────────────
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.allowedUDPPorts = [ 5353 ]; # mDNS (avahi)
  networking.firewall.allowedTCPPorts = [ 3000 9090 9100 ]; # Grafana / Prometheus / node exporter

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # ─────────────────────────────────
  # 3. ロケール・言語環境（i18n）
  # ─────────────────────────────────
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

  # ─────────────────────────────────
  # 4. フォント設定
  # ─────────────────────────────────
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
      # Noto CJKはVariable Font(TTC)形式で、Steamの内蔵CEFがこれを正しく
      # 描画できず日本語が文字化けするため、非VFのMigu/IPAを先頭に置く
      defaultFonts = {
        serif          = [ "IPAMincho" "Noto Serif CJK JP" ];
        sansSerif      = [ "Migu 1C" "Noto Sans CJK JP" ];
        monospace      = [ "Migu 1M" ];
      };
    };
  };

  # ─────────────────────────────────
  # 5. デスクトップ環境
  # ─────────────────────────────────
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

  # ─────────────────────────────────
  # 6. ハードウェア・デバイス（GPU / グラフィックス）
  # ─────────────────────────────────
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # initrd の時点で nvidia を early KMS ロードし、起動時の画面遷移を安定させる
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_drm" "nvidia_uvm" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.printing.enable = true;

  # ─────────────────────────────────
  # 7. サウンド・メディア
  # ─────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ─────────────────────────────────
  # 8. 監視（Prometheus / Grafana / node exporter）
  # ─────────────────────────────────
  services.prometheus = {
    enable = true;
    port = 9090;
    # デフォルトの1分間隔だとNode Exporter Fullダッシュボードの$__rate_interval
    # (4×scrape_interval)が狭い時間範囲でNo dataになるため15秒に短縮
    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [
      {
        job_name = "mac";
        static_configs = [{
          targets = [ "192.168.1.5:9100" ];
        }];
      }
      {
        job_name = "nixos-self";
        static_configs = [{
          targets = [ "localhost:9100" ];
        }];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "0.0.0.0"; # LAN内の他マシンから見られるようにする
      http_port = 3000;
    };
    # Grafana 26.05でsecret_keyのデフォルト値が廃止されたため、file providerで供給する
    # (鍵はNix storeに置かず /var/lib/grafana/secret_key に生成する)
    settings.security.secret_key = "$__file{/var/lib/grafana/secret_key}";

    # データソースとダッシュボードを宣言的にプロビジョニングする
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:9090";
          uid = "prometheus";
          isDefault = true;
        }
      ];
      dashboards.settings.providers = [
        {
          name = "default";
          options.path = "/etc/grafana-dashboards";
        }
      ];
    };
  };

  environment.etc."grafana-dashboards/mac-node-exporter.json".source = ./grafana/mac-node-exporter.json;

  # Grafanaの secret_key を初回起動時にランダム生成し、Nix store外(/var/lib)に保管する
  system.activationScripts.grafanaSecretKey = ''
    if [ ! -f /var/lib/grafana/secret_key ]; then
      mkdir -p /var/lib/grafana
      ${pkgs.openssl}/bin/openssl rand -hex 32 > /var/lib/grafana/secret_key
      chmod 600 /var/lib/grafana/secret_key
      chown grafana:grafana /var/lib/grafana/secret_key
    fi
  '';

  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
  };

  # ─────────────────────────────────
  # 9. リモートデスクトップ・ゲームストリーミング
  # ─────────────────────────────────
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

  # ─────────────────────────────────
  # 10. ユーザー・グループ設定
  # ─────────────────────────────────
  users.users."tomo" = {
    isNormalUser = true;
    description = "tomo";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ ];
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

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

  # ─────────────────────────────────
  # 11. ゲーム・Steam
  # ─────────────────────────────────
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };
  programs.gamemode.enable = true;

  # ─────────────────────────────────
  # 12. ツール・アプリケーション
  # ─────────────────────────────────
  programs.firefox.enable = true;
  programs.direnv.enable = true;

  nixpkgs.config.allowUnfree = true;

  # ─────────────────────────────────
  # 13. システムパッケージ
  # ─────────────────────────────────
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

  # ─────────────────────────────────
  # 14. セキュリティ・SSH
  # ─────────────────────────────────
  services.openssh.enable = true;

  # ─────────────────────────────────
  # 14.5 ファイル共有 (Samba)
  # ─────────────────────────────────
  # tomo の Public フォルダを LAN 内に公開する。パスワードは
  # `sudo smbpasswd -a tomo` で別途設定する必要がある(Nix宣言だけでは作れない)。
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "nixos";
        "netbios name" = "nixos";
        "security" = "user";
        "map to guest" = "never";
      };
      public = {
        "path" = "/home/tomo/Public";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "tomo";
        "force user" = "tomo";
        "force group" = "users";
      };
    };
  };

  # MacのFinderの「ネットワーク」やLinuxのファイルマネージャーからSMB共有が
  # 自動発見されるよう、avahi経由でSMBサービスをアナウンスする
  services.avahi.publish.userServices = true;
  environment.etc."avahi/services/smb.service".text = ''
    <?xml version="1.0" standalone='no'?>
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    <service-group>
      <name replace-wildcards="yes">%h</name>
      <service>
        <type>_smb._tcp</type>
        <port>445</port>
      </service>
    </service-group>
  '';

  # ─────────────────────────────────
  # 15. 追加SSD (1TB)
  # ─────────────────────────────────
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/f15a48a7-b9d4-4f16-b535-0be9ca5540b2";
    fsType = "ext4";
  };

  # ─────────────────────────────────
  # 16. バージョン固定
  # ─────────────────────────────────
  system.stateVersion = "26.05";
}
