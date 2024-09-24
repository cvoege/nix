{ config, pkgs, ... }:

let
  isDarwin = true;
  # successPromptChar = if isDarwin then "ᛗ" else "ᛥ";
  successPromptChar = "👌";
  errorPromptChar = "👀";


  workEmail = "colton@beacons.ai";
  firstName = "Colton";
  lastName = "Voege";
  nameHint = "V as in Victor";
  homePath = builtins.getEnv "HOME";
  username = builtins.getEnv "USER";
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = username;
  home.homeDirectory = homePath;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

    pkgs.python311
    pkgs.bash-completion
    pkgs.fd
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gnutar
    pkgs.htop
    pkgs.jq
    pkgs.just
    pkgs.nix-direnv
    pkgs.nix-bash-completions
    pkgs.nix-index
    pkgs.nix-info
    pkgs.nixpkgs-fmt
    pkgs.nodejs_20
    pkgs.openssh
    pkgs.postgresql
    pkgs.shellcheck
    pkgs.unzip
    pkgs.wget
    pkgs.which
    pkgs.zip
    pkgs.devenv
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/colton/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
      # Fuck you keith
      EDITOR = "nano";
      HISTCONTROL = "ignoreboth";
      PAGER = "less";
      LESS = "-iR";
      BASH_SILENCE_DEPRECATION_WARNING = "1";
      USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
      DO_NOT_TRACK = "1";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship.enable = true;
  programs.starship.settings = {
    add_newline = false;
    character = rec {
      success_symbol = "[${successPromptChar}](bright-green)";
      error_symbol = "[${errorPromptChar}](bright-red)";
    };
    directory.style = "fg:#d442f5";
    nix_shell = {
      pure_msg = "";
      impure_msg = "";
      format = "via [$symbol$state]($style) ";
    };
    kubernetes = {
      disabled = true;
      style = "fg:#326ce5";
    };

    # disabled plugins
    aws.disabled = true;
    cmd_duration.disabled = true;
    gcloud.disabled = true;
    package.disabled = true;
  };

  programs.tmux = {
    enable = true;
    tmuxp.enable = true;
    historyLimit = 500000;
    shortcut = "j";
    extraConfig = ''
      # ijkl arrow key style pane selection
      bind -n M-j select-pane -L
      bind -n M-i select-pane -U
      bind -n M-k select-pane -D
      bind -n M-l select-pane -R

      # split panes using | and -
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %

      set-option -g mouse off
    '';
  };

  programs.bash = {
    enable = true;
    inherit (config.home) sessionVariables;

    historyFileSize = -1;
    historySize = -1;
    shellAliases = {
      ls = "ls --color=auto";
      l = "exa -alFT -L 1";
      ll = "ls -ahlFG";
      dev = "${homePath}/code/beacons/dev.sh";
    };

    initExtra = ''
      shopt -s histappend
      set +h

      export DO_NOT_TRACK=1

      # add local scripts to path
      export PATH="$PATH:$HOME/.bin/:$HOME/.local/bin"

    '' + (if isDarwin then ''
      [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
      [[ -d /Applications/Docker.app/Contents/Resources/bin/ ]] && export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin/"
      alias o=open
    '' else ''
      alias o=xdg-open
    '') + ''
      export NIX_HOME_PATH="$HOME/.config/home-manager"
      ehome() { code "$NIX_HOME_PATH/home.nix" ; }

      codedir() { EDITOR="code --wait" , vidir "$@"; }

      # bash completions
      source ~/.nix-profile/etc/profile.d/bash_completion.sh
      source ~/.nix-profile/share/bash-completion/completions/git
      source ~/.nix-profile/share/bash-completion/completions/ssh

      if test -f ~/google-cloud-sdk/completion.bash.inc ; then
        source ~/google-cloud-sdk/completion.bash.inc
      fi
      if test -f ~/google-cloud-sdk/path.bash.inc ; then
        source ~/google-cloud-sdk/path.bash.inc
      fi
      if test -d ~/google-cloud-sdk/bin/ ; then
        export PATH="$PATH:$HOME/google-cloud-sdk/bin/"
      fi

      # ex:
      #   gu - commits with message guh
      #   gu a message here - commits with message "a message here"
      gu() {
        MSG="guh"
        if [ $# -gt 0 ] ; then
          MSG="$@"
        fi
        git add -A
        git commit -nm "$MSG"
      }

      # ex:
      #   guh - commits and pushes with message guh
      #   guh a message here - commits and pushes with message "a message here"
      guh() {
        MSG="guh"
        if [ $# -gt 0 ] ; then
          MSG="$@"
        fi
        git add -A
        git commit -nm "$MSG"
        git put
      }
    '';
  };

  programs.htop.enable = true;
  programs.dircolors.enable = true;

  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    userName = "${firstName} ${lastName}";
    userEmail = workEmail;
    lfs = {
      enable = true;
    };
    aliases = {
      co = "checkout";
      dad = "add";
      cam = "commit -am";
      ca = "commit -a";
      cm = "commit -m";
      st = "status";
      br = "branch -v";
      ff = "merge --ff-only";
      branch-name = "!git rev-parse --abbrev-ref HEAD";
      # Push current branch
      put = "!git push origin $(git branch-name)";
      # Pull without merging
      get = "!git pull origin $(git branch-name)";
      # Pull Master without switching branches
      got =
        "!f() { CURRENT_BRANCH=$(git branch-name) && git checkout $1 && git pull origin $1 --ff-only && git checkout $CURRENT_BRANCH;  }; f";
      lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
      lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";

      # delete local branch and pull from remote
      fetchout =
        "!f() { git co main; git branch -D $@; git fetch && git co $@; }; f";
      pufl = "!git push origin $(git branch-name) --force-with-lease";
      putf = "put --force-with-lease";
      shake = "remote prune origin";
    };
    extraConfig = {
      color.ui = true;
      push.default = "simple";
      pull.ff = "only";
      init = {
        defaultBranch = "main";
      };
      advice.addEmptyPathspec = false;
      core = {
        editor = "code --wait";
      };
    };
  };
}
