{ pkgs, ... }:

{
  imports = [
    # services/pretalx.nix
    services/pretix.nix
  ];

  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host all all ::1/128 trust
    '';
    initialScript = pkgs.writeText "backend-initScript" ''
      CREATE ROLE pretalx WITH LOGIN PASSWORD 'pretalx' CREATEDB;
      CREATE DATABASE pretalx;
      GRANT ALL PRIVILEGES ON DATABASE pretalx TO pretalx;

      CREATE ROLE pretix WITH LOGIN PASSWORD 'pretix' CREATEDB;
      CREATE DATABASE pretix;
      GRANT ALL PRIVILEGES ON DATABASE pretix TO pretix;
    '';
  };

  services.redis.enable = true;

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    virtualHosts."cfp.nixos.paris" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:8003";
      };
    };
    virtualHosts."tickets.nixos.paris" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:8004";
      };
    };
  };
  # Optional: You can configure the email address used with Let's Encrypt.
  # This way you get renewal reminders (automated by NixOS) as well as expiration emails.
  security.acme.certs = {
    "cfp.nixos.paris".email = "contact@nixos.paris";
    "tickets.nixos.paris".email = "contact@nixos.paris";
  };
}
