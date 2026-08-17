{
  description = "rustdesk-infra — self-hosted RustDesk relay on AWS (IaC)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = nixpkgs.lib.systems.flakeExposed;
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;  # terraform is BSL-licensed
            };
          };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              terraform
              terraform-ls
              awscli2
              tflint
              sops
              age
            ];

            shellHook = ''
              echo "rustdesk-infra dev shell loaded"
              echo "  Terraform: $(terraform --version | head -1)"
              echo "  AWS CLI:   $(aws --version 2>&1 | head -1)"
              echo "  sops:      $(sops --version 2>&1 | head -1)"
            '';
          };
        }
      );
    };
}
