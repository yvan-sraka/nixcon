{ pkgs ? import <nixpkgs> { }
,
}:

let
  poetry2nix = pkgs.poetry2nix;
in
(poetry2nix.mkPoetryApplication {
  projectDir = ./.;
  doCheck = false;
  overrides = poetry2nix.overrides.withDefaults (self: super: {
    pretalx = super.pretalx.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [
        pkgs.sass
      ];
    });

    cssutils = super.cssutils.override {
      preferWheel = true;
    };

    django-scopes = super.django-scopes.override {
      preferWheel = true;
    };

  });
})/*.overrideAttrs(old: {
  inherit (old.passthru.python.pythonPackages.pretalx) pname name version;
  })*/
