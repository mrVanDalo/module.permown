A NixOS module to enforce permissions on a path and it's sub-directories.

For example to make sure that `/srv/www/` always belongs to `nginx:www`, you can use this module
in the following way.

``` nix
services.permown."/srv/www" = {
  owner = "nginx";
  group = "www";
};
```

## Acknowledgement

The code is extracted from [stockholm the krebs repository](https://cgit.krebsco.de/stockholm/tree/krebs/3modules/permown.nix) and slightly modified.
