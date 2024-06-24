## Getting Started

Add this repository as a channel:

```nix
$ nix-channel --add https://github.com/nix-community/plasma-manager/archive/trunk.tar.gz plasma-manager
```

Update / unpack the channel:

```nix
$ nix-channel --update plasma-manager
```

Add to your configuration file, for example `~/.config/home-manager/plasma.nix`:

```nix
{ pkgs, ...}:
{
  imports = [
    <plasma-manager/modules>
  ];

  programs = {
    plasma = {
      enable = true;
      # etc.
    };
  };
}
```

