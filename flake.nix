{
  description = "Somebody Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";

    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-24.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-homebrew.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.inputs.nix-darwin.follows = "nix-darwin";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
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
          kubo
          tldr
          wget
          dust
        ];

      # List services that you want to enable:
      homebrew = {
        enable = true;
        brews = [
          "mas"
          "eza"
          "htop"
          "cmake"
          "protobuf"
	      "golang"
        ];
        casks = [
          "chromium"
          "ngrok"
          "sage"
        ];
        masApps = {};
        onActivation.cleanup = "zap";
      };

      fonts.packages = [
        (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
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

      system.defaults = {
        dock.autohide = true;
        finder.FXPreferredViewStyle = "clmv";
        loginwindow.GuestEnabled = false;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
        NSGlobalDomain.KeyRepeat = 2;
      };

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;

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
              user = "kyrylr";
              autoMigrate = true;
            };
          }
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;

            users = {
              kyrylr = { lib, pkgs, ... }: {
                home = {
                  stateVersion = lib.mkForce "24.11";
                  homeDirectory = lib.mkForce "/Users/kyrylr";
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
                      "iterm2"
                    ];
                  };

                  shellAliases = {
                    mkdir = "mkdir -p";
                    wake  = "echo \a";
                    ll    = "eza -lhb --git";
                    lla   = "eza -lhba --git";
                    ls    = "eza --git";
                    please = "sudo";
                    sc    = "ssh root@192.168.1.245";
                  };

                  sessionVariables = {
                    NVM_DIR      = "$HOME/.nvm";
                    BUN_INSTALL  = "$HOME/.bun";
                    PNPM_HOME    = "$HOME/Library/pnpm";
                    SCR          = "root@192.168.1.245";
                    ANDROID_NDK  = "/Users/kyrylr/Library/Android/sdk/ndk/23.1.7779620";
                  };

                  # Extra lines appended to `.zshenv` (executed by every new shell).
                  envExtra = ''
                    # Source other environment scripts
                    . "$HOME/Library/Application Support/org.dfinity.dfx/env"
                    . "$HOME/.cargo/env"

                    # Extend PATH
                    export PATH="$PATH:.cargo/bin"
                    export PATH="$PATH:$BUN_INSTALL/bin"
                    export PATH="$PATH:/Users/kyrylr/.foundry/bin"

                    # Java
                    export JAVA_HOME=$(/usr/libexec/java_home)
                    export PATH="$JAVA_HOME/bin:$PATH"

                    # Add pnpm to PATH if not present
                    case ":$PATH:" in
                      *":$PNPM_HOME:"*) ;;
                      *) export PATH="$PNPM_HOME:$PATH" ;;
                    esac

                    # Go
                    export PATH="$PATH:$HOME/go/bin"
                  '';

                  # Extra lines appended to `.zshrc` (run after oh-my-zsh initialization).
                  initExtra = ''
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
