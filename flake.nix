{
  description = "template for hydenix";

  inputs = {
    nixpkgs = {
      # url = "github:nixos/nixpkgs/nixos-unstable"; # uncomment this if you know what you're doing
      follows = "hydenix/nixpkgs"; # then comment this
    };
    hydenix.url = "github:richen604/hydenix";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    mcp-hub.url = "github:ravitemer/mcp-hub";
    mcphub-nvim.url = "github:ravitemer/mcphub.nvim";
    older-pipewire.url = "github:NixOS/nixpkgs/2631b0b7abcea6e640ce31cd78ea58910d31e650";
  };

  outputs = { ... }@inputs:
    let
      HOSTNAME = "xps13-9320";
      system = "x86_64-linux";

      # pkgs-unstable = import inputs.nixpkgs-unstable {
      #   inherit system;
      #   config.allowUnfree = true;
      # };

      hydenixConfig = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        # specialArgs = { inherit inputs pkgs-unstable; };
        modules = [ ./host/config.nix ];
      };
    in {
      nixosConfigurations.nixos = hydenixConfig;
      nixosConfigurations.${HOSTNAME} = hydenixConfig;
      nixosConfigurations.default = hydenixConfig;
    };
}
