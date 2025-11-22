# Install

```bash
# Install nix
sh <(curl -L https://nixos.org/nix/install)

# Install home manager
# v unstable
# nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
# nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
# nix-channel --add nixpkgs https://nixos.org/channels/nixpkgs-unstable nixpkgs

# Pinned channels, preferred rn
# See: https://status.nixos.org/
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install

# Show some basic info about your machine
nix-shell --packages nix-info --run "nix-info --host-os --markdown --sandbox"

# nixpkgs version
nix-instantiate --eval -E '(import <nixpkgs> {}).lib.version'

# home-manager version
home-manager --version

cd ~/.config/home-manager
rm -rf ~/.config/home-manager/*
git clone git@github.com:cvoege/nix.git .

home-manager switch
nix-env -iA devenv -f https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable
```

# Update

```bash
sudo nix-channel --update
# See https://nix-community.github.io/home-manager/#sec-install-standalone for tar.gz
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```
