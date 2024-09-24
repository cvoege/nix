# Install

```bash
# Install nix
sh <(curl -L https://nixos.org/nix/install)

# Install home manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install


cd ~/.config/home-manager
rm -rf ~/.config/home-manager/*
git clone git@github.com:cvoege/nix.git .

home-manager switch
```
