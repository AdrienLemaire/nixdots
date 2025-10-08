{
  description = "template for hydenix";

  inputs = {
    # Your nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable = { url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };

    # Hydenix
    hydenix = {
      # Available inputs:
      # Main: github:richen604/hydenix
      # Commit: github:richen604/hydenix/<commit-hash>
      # Version: github:richen604/hydenix/v1.0.0
      url = "github:richen604/hydenix";
      # uncomment the below if you know what you're doing, hydenix updates nixos-unstable every week or so
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";      
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware Configuration's, used in ./configuration.nix. Feel free to remove if unused
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    mcp-hub.url = "github:ravitemer/mcp-hub";
    mcphub-nvim.url = "github:ravitemer/mcphub.nvim";
    older-pipewire.url = "github:NixOS/nixpkgs/2631b0b7abcea6e640ce31cd78ea58910d31e650";
  };

  outputs = { ... }@inputs:
    let
      HOSTNAME = "xps13-9320";
      system = "x86_64-linux";

      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      hydenixConfig = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-unstable; };
        modules = [ ./host/config.nix ];
      };
    in {
      nixosConfigurations.nixos = hydenixConfig;
      nixosConfigurations.${HOSTNAME} = hydenixConfig;
      nixosConfigurations.default = hydenixConfig;
    };
}
