{
  description = "template for hydenix";

  inputs = {
    # User's nixpkgs - for user packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable = { url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };

    # Hydenix and its nixpkgs - kept separate to avoid conflicts
    hydenix = {
      # Available inputs:
      # Main: github:richen604/hydenix
      # Dev: github:richen604/hydenix/dev
      # Commit: github:richen604/hydenix/<commit-hash>
      # Version: github:richen604/hydenix/v1.0.0
      url = "github:richen604/hydenix";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ghostty.url = "github:ghostty-org/ghostty";
    mcp-hub.url = "github:ravitemer/mcp-hub";
    mcphub-nvim.url = "github:ravitemer/mcphub.nvim";
    # whisper-overlay = {
    #   # url = "github:oddlama/whisper-overlay";
    #   url = "path:/home/dori/Projects/3rdPart/ai/whisper-overlay";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    older-pipewire.url = "github:NixOS/nixpkgs/2631b0b7abcea6e640ce31cd78ea58910d31e650";
  };

  outputs = { ... }@inputs:
    let
      HOSTNAME = "xps13-9320";

      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit (inputs.hydenix.lib) system;
        config.allowUnfree = true;
      };

      hydenixConfig = inputs.hydenix.inputs.hydenix-nixpkgs.lib.nixosSystem {
        inherit (inputs.hydenix.lib) system;
        specialArgs = { inherit inputs pkgs-unstable; };
        modules = [ ./config.nix ];
      };
    in {
      nixosConfigurations.nixos = hydenixConfig;
      nixosConfigurations.${HOSTNAME} = hydenixConfig;
    };
}
