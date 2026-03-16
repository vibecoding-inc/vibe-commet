{
  description = "Flutter Development Environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
            permittedInsecurePackages = [ "olm-3.2.16" ];
          };
        };
        aapt2buildToolsVersion = "34.0.0";
        androidComposition = pkgs.androidenv.composeAndroidPackages {
          buildToolsVersions = [
            "30.0.3"
            aapt2buildToolsVersion
          ];
          platformVersions = [
            "28"
            "29"
            "30"
            "31"
            "32"
            "33"
            "34"
          ];
          includeNDK = true;
          ndkVersions = [ "21.4.7075529" ];
          cmakeVersions = [ "3.18.1" ];
          abiVersions = [
            "armeabi-v7a"
            "arm64-v8a"
          ];
        };
        androidSdk = androidComposition.androidsdk;

        libraries = with pkgs; [
              olm
              libdrm
              mesa
        ];

        packages = with pkgs; [
              flutter
              androidSdk
              jdk17
              ninja
              gtk3
              mpv
              ffmpeg
              mimalloc
              libepoxy
              dart
              libass
              pkg-config
              android-tools
              android-studio
              bashInteractive
        ];

        # Named source path so sourceRoot is predictable in the Nix sandbox.
        commetSrc = builtins.path {
          name = "commet-source";
          path = ./.;
        };

        commet = pkgs.flutter.buildFlutterApplication {
          pname = "commet";
          version = "0.4.1+824";

          src = commetSrc;
          # Build from the commet/ workspace member; the workspace root (with
          # pubspec.lock and sibling packages) remains accessible as "../".
          sourceRoot = "commet-source/commet";

          # pubspec.lock.json is the JSON-serialised form of pubspec.lock.
          # It MUST be kept in sync whenever pubspec.lock is updated; run:
          #   python3 -c "import yaml, json, sys; json.dump(yaml.safe_load(sys.stdin), sys.stdout)" \
          #     < pubspec.lock > pubspec.lock.json
          pubspecLock = pkgs.lib.importJSON ./pubspec.lock.json;

          # SHA-256 hashes for every git-sourced dependency declared in
          # pubspec.lock.  These are placeholders; to obtain the real hashes:
          #   1. Run `nix build` – the build will fail with a hash mismatch.
          #   2. Copy the "got:" sha256 value from each error message.
          #   3. Replace the corresponding lib.fakeHash below with that value.
          gitHashes = {
            calendar_view = pkgs.lib.fakeHash;
            desktop_webview_window = pkgs.lib.fakeHash;
            dynamic_color = pkgs.lib.fakeHash;
            flutter_highlighter = pkgs.lib.fakeHash;
            flutter_html = pkgs.lib.fakeHash;
            flutter_local_notifications = pkgs.lib.fakeHash;
            flutter_local_notifications_linux = pkgs.lib.fakeHash;
            markdown = pkgs.lib.fakeHash;
            matrix = pkgs.lib.fakeHash;
            matrix_dart_sdk_drift_db = pkgs.lib.fakeHash;
            receive_intent = pkgs.lib.fakeHash;
            signal_sticker_api = pkgs.lib.fakeHash;
            starfield = pkgs.lib.fakeHash;
          };

          nativeBuildInputs = with pkgs; [
            pkg-config
            ninja
            cmake
            clang
          ];

          buildInputs = with pkgs; [
            gtk3
            mpv
            libepoxy
            olm
            libdrm
            mesa
            mimalloc
            libass
            ffmpeg
          ];

          extraBuildArgs = [
            "--dart-define"
            "PLATFORM=linux"
            "--dart-define"
            "BUILD_MODE=release"
          ];
        };

      in
      {
        packages.default = commet;

        devShell =
          with pkgs;
          mkShell rec {
            ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
            ANDROID_JAVA_HOME = jdk17.home;
            JAVA_8_HOME = jdk8.home;
            JAVA_17_HOME = jdk17.home;
            SHELL = "${pkgs.bashInteractive}/bin/bash";
            GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_SDK_ROOT}/build-tools/${aapt2buildToolsVersion}/aapt2";
            LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath libraries}";
            buildInputs = libraries ++ packages;
          };
      }
    );
}
