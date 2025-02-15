{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages."${system}";
    lib = nixpkgs.lib;
  in {
    formatter."${system}" = pkgs.alejandra;

    packages."${system}".default = pkgs.callPackage ./default.nix {
      lvm2 = pkgs.lvm2.override {enableCmdlib = true;};
    };

    devShells."${system}" = rec {
      default = pkgs.mkShell {
        packages = with pkgs; [
          jq
          kubectl
          kubernetes-helm
          minikube
        ];
      };
    };
  };
}
