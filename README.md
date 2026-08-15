# nixos-config

このマシン(`nixos`)の `/etc/nixos` をそのままGit管理しているリポジトリ。

## 構成

- `configuration.nix` — システム設定本体。変更したらここを編集する。
- `hardware-configuration.nix` — `nixos-generate-config` が生成した、このマシン固有のハードウェア設定(ディスクのUUID、カーネルモジュール等)。**手動で編集しない。**
- `configuration.nix.bak` — `.gitignore` 対象のローカル控え。リポジトリには含まれない。

## 日常の運用

`configuration.nix` を編集したら、反映前に必ずビルドして確認する。

```sh
sudo nixos-rebuild switch
```

問題なければコミット。変更内容が複数のトピックにまたがる場合は、トピックごとにコミットを分ける。

```sh
git add configuration.nix
git commit -m "変更内容"
git push origin master
```

## 復元方法

### 同一マシンへの再インストール

このマシンのディスク構成が変わっていない前提。

1. NixOSインストーラで最小構成インストールを行う。
2. このリポジトリを `/etc/nixos` に配置する。

   ```sh
   sudo mv /etc/nixos /etc/nixos.orig
   sudo git clone https://github.com/tommy-mars/nixos-config.git /etc/nixos
   ```

3. `hardware-configuration.nix` はディスクのUUIDなどマシン固有の情報を含むため、インストーラが `/etc/nixos.orig/hardware-configuration.nix` に生成したものと、リポジトリ内のものが一致するか確認する。パーティション構成を変えていなければ通常は一致するはず。異なる場合はインストーラ生成版で上書きする。

   ```sh
   sudo cp /etc/nixos.orig/hardware-configuration.nix /etc/nixos/hardware-configuration.nix
   ```

4. ビルドして起動設定を反映する。

   ```sh
   sudo nixos-rebuild switch
   ```

### 別マシン・新規ハードウェアへの適用

`hardware-configuration.nix` はこのマシン専用なので、そのまま使い回さない。

1. NixOSインストーラで対象マシン用に `nixos-generate-config` を実行し、そのマシン用の `hardware-configuration.nix` を生成する。
2. このリポジトリの `configuration.nix` を `/etc/nixos/configuration.nix` として配置し、生成された `hardware-configuration.nix` はそのまま残す(上書きしない)。
3. GPU(`hardware.nvidia`)や `networking.hostName` など、マシン固有になりうる設定を対象マシンに合わせて調整する。
4. `sudo nixos-rebuild switch` で反映する。

## 主な設定内容

- 日本語ロケール・入力(`fcitx5` + Mozc)
- COSMICデスクトップ、NVIDIA(open kernel module)、early KMS
- Steam(`programs.steam`)、GameMode、日本語CJKフォントはSteamの文字化け対策でMigu/IPA(非Variable Font)を優先
- Sunshineによるリモートゲームストリーミング(CUDA有効ビルド)
- Pipewireオーディオ
