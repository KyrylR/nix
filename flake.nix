{
  description = "Somebody Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-homebrew.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.inputs.nix-darwin.follows = "nix-darwin";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager, ... }:
  let
    configuration = { pkgs, config, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        with pkgs; [
          neovim
          tmux
          texliveFull
          kubo # IPFS node
          tldr
          wget
          dust
          bat
          tree
          ninja
          biber
          grpcurl
        ];

      # List services that you want to enable:
      homebrew = {
        enable = true;
        brews = [
          "mas"
          "eza"
          "btop"
          "cmake"
          "protobuf"
	      "golang"
	      "lld"
	      "binutils"
	      "uv"
	      "pipx"
	      "rustup"
	      "foundry"
	      "openjdk"
	      "oven-sh/bun/bun"
	      "nvm"
	      "emscripten"
	      "yt-dlp"
	      "ffmpeg"
	      "git-filter-repo"
	      "cocoapods"
	      "virtualenv"
	      "gnu-getopt"
	      "gnu-sed"
	      "autoconf"
	      "automake"
	      "libtool"
	      "swig"
	      "just"
	      "coreutils"
        ];
        casks = [
          "chromium"
          "ngrok"
          "sage"
          "ghostty"
          "slack"
          "telegram-desktop"
          "spotify"
          "discord"
          "zoom"
          "signal"
          "temurin@17"
        ];
        masApps = {};
        onActivation.cleanup = "zap";
      };

      fonts.packages = [
        pkgs.nerd-fonts.jetbrains-mono
      ];

      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
        pkgs.lib.mkForce ''
          # Set up applications.
          echo "setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while read -r src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';

      system.primaryUser = "inter";

      system.defaults = {
        dock.autohide = true;
        finder.FXPreferredViewStyle = "clmv";
        loginwindow.GuestEnabled = false;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
        NSGlobalDomain.KeyRepeat = 2;
      };

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    darwinConfigurations."first" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "inter";
              autoMigrate = true;
            };
          }
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;

            users = {
              inter = { lib, pkgs, ... }: {
                home = {
                  stateVersion = lib.mkForce "24.11";
                  homeDirectory = lib.mkForce "/Users/inter";
                };

                programs.zsh = {
                  enable = true;

                  oh-my-zsh = {
                    enable = true;
                    plugins = [
                      "git"
                      "rust"
                      "docker"
                      "docker-compose"
                      "bun"
                      "nvm"
                      "node"
                    ];
                  };

                  shellAliases = {
                    mkdir = "mkdir -p";
                    wake  = "echo \a";
                    ll    = "eza -lhb --git";
                    lla   = "eza -lhba --git";
                    ls    = "eza --git";
                    please = "sudo";
                    rc    = "cargo fmt --all && cargo clippy --all-targets --all-features --fix --allow-dirty --allow-staged -- -D warnings -D clippy::all -D clippy::pedantic -D clippy::nursery -D clippy::cargo -A clippy::multiple_crate_versions";
                  };

                  sessionVariables = {
                    NVM_DIR      = "$HOME/.nvm";
                    BUN_INSTALL  = "$HOME/.bun";
                    PNPM_HOME    = "$HOME/Library/pnpm";
                    SCR          = "root@192.168.1.245";
                    ANDROID_NDK  = "/Users/inter/Library/Android/sdk/ndk/23.1.7779620";
                    JAVA_HOME    = "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home";
                  };

                  # Extra lines appended to `.zshenv` (executed by every new shell).
                  envExtra = ''
                    # Source other environment scripts
                    . "$HOME/.cargo/env"
                    . "$HOME/.keystore/env"

                    # Extend PATH
                    export PATH="$PATH:.cargo/bin"
                    export PATH="$PATH:$BUN_INSTALL/bin"
                    export PATH="$PATH:/Users/inter/.foundry/bin"

                    # Java
                    export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
                    export PATH="/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home/bin:$PATH"

                    # Add pnpm to PATH if not present
                    case ":$PATH:" in
                      *":$PNPM_HOME:"*) ;;
                      *) export PATH="$PNPM_HOME:$PATH" ;;
                    esac

                    # Go
                    export PATH="$PATH:$HOME/go/bin"

                    export GOPRIVATE=github.com/openioncom/*

                    export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

                    export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
                    export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"

                    export PATH="/Users/inter/.local/share/solana/install/active_release/bin:$PATH"
                    export PATH="/Users/inter/.local/bin:$PATH"

                    export COREPACK_ENABLE_AUTO_PIN=0
                  '';

                  initContent = ''
                  if command -v rustup &> /dev/null; then
                    export PATH="$PATH:$HOME/.cargo/bin"
                    source "$HOME/.cargo/env" 2>/dev/null || true
                  fi

                  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
                  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

                  MYNAME="inter"
                  git_branch() {
                    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
                    if [[ -n $branch ]]; then
                      echo "%F{magenta}($branch)%f"
                    fi
                  }

                  PROMPT='%F{cyan}'$MYNAME'%f %F{yellow}%1~%f $(git_branch) %(?.%F{green}✔%f.%F{red}✘%f) '
                  '';
                };
              };
            };
          };
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."first".pkgs;
  };
}
