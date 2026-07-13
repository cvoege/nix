{ config, pkgs, ... }:

let
  isDarwin = true;
  # successPromptChar = if isDarwin then "ᛗ" else "ᛥ";
  successPromptChar = "👌";
  errorPromptChar = "👀";


  workEmail = "colton@getaleph.com";
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

    pkgs.python313
    pkgs.bash-completion
    pkgs.fd
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gnutar
    pkgs.htop
    pkgs.jq
    pkgs.just
    pkgs.coreutils
    pkgs.nix-direnv
    pkgs.nix-bash-completions
    pkgs.nix-index
    pkgs.nix-info
    pkgs.nixpkgs-fmt
    # pkgs.nodejs_24
    pkgs.yarn
    pkgs.ncdu
    pkgs.gnupg
    pkgs.pnpm
    pkgs.openssh
    pkgs.postgresql
    pkgs.shellcheck
    pkgs.unzip
    pkgs.wget
    pkgs.which
    pkgs.zip
    # pkgs.codex
    # pkgs.mongodb-cli
    # pkgs.mongodb-tools
    # pkgs.ruby
    pkgs.devenv
    # pkgs.claude-code
    pkgs.opentofu
    pkgs.bun
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # PR-stacking utilities. Named git-* so they become `git stack` (with a
    # `git stack restack` subcommand).
    # See ./bin/*; ~/.bin is already on PATH (set in programs.bash.initExtra).
    ".bin/git-stack" = { source = ./bin/git-stack; executable = true; };

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

      d = "docker";
      da = "docker ps -a";
      di = "docker images";
      de = "docker exec -it";
      dr = "docker run --rm -it";
      daq = "docker ps -aq";
      drma = "docker stop $(docker ps -aq) && docker rm -f $(docker ps -aq)";
      dc = "docker-compose";
      k = "kubectl";

      # PR stacking (script lives in ./bin, exposed as `git stack`)
      restack = "git stack restack";
      gstk = "git stack";
    };

    initExtra = ''
      shopt -s histappend
      set +h

      export DO_NOT_TRACK=1

      # Re-assert nix paths ahead of macOS path_helper, which /etc/profile runs on
      # every login shell and which re-prepends /usr/bin, /bin, etc. to the front of
      # PATH — burying ~/.nix-profile/bin so `bash` resolves to the old /bin/bash 3.2.
      export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:$PATH"

      # add local scripts to path
      export PATH="$PATH:$HOME/.bin/:$HOME/.local/bin"

    '' + (if isDarwin then ''
      [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
      # export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
      # export GEM_HOME=/usr/local/opt/ruby/lib/ruby/gems/3.4.0
      # export GEM_PATH=/usr/local/opt/ruby/lib/ruby/gems/3.4.0
      # [[ -f /Users/$USER/.local/bin/mise ]] && eval "$(/Users/$USER/.local/bin/mise activate bash)"
      # [[ -f /Users/$USER/.local/bin/mise ]] && eval "$(/Users/$USER/.local/bin/mise activate --shims)"
      export PATH="/Users/$USER/.local/share/mise/shims:$PATH"
      [[ -d /Applications/Docker.app/Contents/Resources/bin/ ]] && export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin/"
      alias o=open
      if [[ -d /opt/homebrew/etc/bash_completion.d ]]; then
        for f in /opt/homebrew/etc/bash_completion.d/*; do
          [[ -f "$f" ]] && source "$f"
        done
      fi
      export XDG_CONFIG_HOME="$HOME/.config"
    '' else ''
      alias o=xdg-open
    '') + ''
      export NIX_HOME_PATH="$HOME/.config/home-manager"
      ehome() { zed "$NIX_HOME_PATH/home.nix" ; }

      codedir() { EDITOR="zed --wait" , vidir "$@"; }

      # bash completions
      source ~/.nix-profile/etc/profile.d/bash_completion.sh
      source ~/.nix-profile/share/bash-completion/completions/git
      source ~/.nix-profile/share/bash-completion/completions/ssh

      if test -f ~/code/gcloud-cli/google-cloud-sdk/completion.bash.inc ; then
        source ~/code/gcloud-cli/google-cloud-sdk/completion.bash.inc
      fi
      if test -f ~/code/gcloud-cli/google-cloud-sdk/path.bash.inc ; then
        source ~/code/gcloud-cli/google-cloud-sdk/path.bash.inc
      fi
      if test -d ~/code/gcloud-cli/google-cloud-sdk/bin/ ; then
        export PATH="$PATH:$HOME/code/gcloud-cli/google-cloud-sdk/bin/"
      fi

      command -v kubectl > /dev/null 2>&1 && complete -F __start_kubectl k
      command -v zed > /dev/null 2>&1 && export EDITOR="zed --wait"

      fixcursor() {
        tput cnorm
      }

      if test -f "$HOME/.certs/localhost-key.pem" ; then
        export LOCALHOST_KEY="$HOME/.certs/localhost-key.pem"
        export LOCALHOST_CERT="$HOME/.certs/localhost.pem"
      fi

      if test -d $HOME/.config/nvm ; then
        export NVM_DIR="$HOME/.config/nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
      fi

      git_main_branch() {
        git branch -r | grep 'HEAD' | sed 's@.*-> origin/@@'
      }

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

      r() {
        pnpm run --filter "@getaleph/$1" "$2"
      }

      # cw <branch> [prompt]
      # Opens a new tmux window running a fresh claude session in a git worktree on <branch>.
      cw() {
        local branch="$1"
        local prompt="$2"

        if [ -z "$branch" ]; then
          echo "usage: cw <branch> [prompt]" >&2
          return 1
        fi

        # Window name: default to the branch name, but for branches shaped like
        # colton/act-123-whatever, use the ticket id (ACT-123) instead.
        local window="$branch"
        if [[ "$branch" =~ ^[a-z]+/([a-z]+-[0-9]+)-.* ]]; then
          window="$(echo "''${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')"
        fi

        # Resolve worktree location and repo root.
        local repo_root worktree
        repo_root="$(git rev-parse --show-toplevel)" || return 1
        worktree="$repo_root/../$(basename "$repo_root")-worktrees/$window"

        # Fetch so we know whether the branch exists on origin, and so we base
        # new branches on the latest trunk.
        git fetch origin --quiet

        if git show-ref --verify --quiet "refs/heads/$branch" ||
           git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
          # Branch already exists: pull it from origin and check it out in the worktree.
          git fetch origin "$branch:$branch" 2>/dev/null || git branch -f "$branch" "origin/$branch"
          git worktree add "$worktree" "$branch" || return 1
        else
          # New branch, always based on the latest trunk. Determine the remote's
          # default branch name (main, trunk, master, ...) rather than assuming.
          local trunk
          trunk="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" ||
            trunk="$(git remote show origin | sed -n 's/.*HEAD branch: //p')"
          if [ -z "$trunk" ]; then
            echo "cw: could not determine origin's default branch" >&2
            return 1
          fi
          git worktree add -b "$branch" "$worktree" "$trunk" || return 1
        fi

        # Open a new tmux window with an empty shell, then type the claude command
        # into it — when claude exits you're back at the shell, so the pane stays.
        local win_id cmd
        win_id="$(tmux new-window -P -F '#{window_id}' -n "$window" -c "$worktree")"
        cmd="claude"
        [ -n "$prompt" ] && cmd="claude $(printf '%q' "$prompt")"
        tmux send-keys -t "$win_id.0" "$cmd" Enter
        tmux split-window -v -t "$win_id" -c "$worktree"
        tmux select-pane -t "$win_id.0"
      }
    '';
  };

  programs.htop.enable = true;
  programs.dircolors.enable = true;

  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    lfs = {
      enable = true;
    };
    settings = {
      user.name = "${firstName} ${lastName}";
      user.email = workEmail;
      alias = {
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
        put = "!git push -u origin $(git branch-name)";
        # Pull without merging
        get = "!git pull origin $(git branch-name)";
        # Pull Master without switching branches
        got =
          "!f() { git fetch origin $1:$1 ; }; f";
        lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
        lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";

        # delete local branch and pull from remote
        fetchout =
          "!f() { git fetch origin $1 --force && git branch -f $1 origin/$1 ; }; f";
        pufl = "!git push -u origin $(git branch-name) --force-with-lease";
        shake = "remote prune origin";
      };

      color.ui = true;
      push.default = "simple";
      pull.ff = "only";
      init = {
        defaultBranch = "main";
      };
      advice.addEmptyPathspec = false;
      core = {
        editor = "zed --wait";
        ignoreCase = false;
      };
    };
  };
}
