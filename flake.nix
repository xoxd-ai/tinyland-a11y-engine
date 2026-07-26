{
  description = "@tummycrypt/tinyland-a11y-engine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bazelisk
            coreutils
            curl
            git
            gnutar
            gzip
            jq
            just
            nodejs_22
            python3
          ];
          shellHook = ''
            echo "tinyland-a11y-engine dev shell"
            echo "  node $(node --version)"
            echo "  npm $(npm --version)"
            echo "  bazelisk $(bazelisk version 2>/dev/null | head -n1)"
          '';
        };
        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
