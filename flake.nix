{
  description = "rook-ceph-dev";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages."${system}";
  in {
    formatter."${system}" = pkgs.alejandra;

    devShells."${system}".default = pkgs.mkShell {
      packages = with pkgs;
        [
          kubectl
          kubernetes-helm
          minikube
        ];
    };
  };
}
