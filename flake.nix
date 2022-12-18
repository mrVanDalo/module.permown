{
  description = "permown flake, a NixOS modul to enforce permissons on folders.";
  outputs = { self, nixpkgs }: {
    nixosModules.permown = {
      imports = [ ./default.nix ];
    };
  };
}
