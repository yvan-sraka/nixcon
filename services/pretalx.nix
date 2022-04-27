{ ... }:

let
  pkgs = import ./unstable.nix { };

  pretalx = (import ../pkgs/pretalx {
    inherit pkgs;
  });

  pythonPackages = pretalx.passthru.pythonPackages;
  gunicorn = pythonPackages.gunicorn;
  python = pythonPackages.python;

  name = "pretalx";
  user = "pretalx";
  server = {
    bind = "127.0.0.1";
    port = "8003";
  };

  environmentFile = pkgs.runCommand "pretalx-environ"
    {
      buildInputs = [ pretalx gunicorn ]; # Sets PYTHONPATH in derivation
    } ''
    cat > $out <<EOF
    PYTHONPATH=$PYTHONPATH
    EOF
  '';

  mkTimer = { description, unit, onCalendar }: {
    inherit description;
    requires = [ "pretalx-migrate.service" ];
    after = [ "network.target" ];
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Persistent = true;
      OnCalendar = onCalendar;
      Unit = unit;
    };
  };


in
{

  users.users."${user}" = {
    isNormalUser = false;
    createHome = true;
    home = "/var/pretalx";
    description = "Pretalx user";
  };

  environment.etc."pretalx/pretalx.cfg".source = ./pretalx.cfg;

  systemd.services.pretalx-migrate = {
    description = "Pretalx DB Migrations";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = environmentFile;
      User = user;
    };
    script = "${pretalx}/bin/pretalx migrate";
  };

  systemd.services.pretalx-web = {
    description = "Pretalx Web Service";
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      EnvironmentFile = environmentFile;
      User = user;
      ExecStart = pkgs.writeScript "webserver" ''
        #!${pkgs.runtimeShell}
        set -euo pipefail

        ${pretalx}/bin/pretalx collectstatic --noinput

        exec ${gunicorn}/bin/gunicorn pretalx.wsgi --name ${name} \
        --workers 3 \
        --log-level=info \
        --bind=${server.bind}:${server.port}
      '';
    };
    wantedBy = [ "multi-user.target" ];
    requires = [ "pretalx-migrate.service" ];
    after = [ "network.target" ];
  };

  systemd.services.pretalx-clearsessions = {
    description = "Pretalx clear sessions";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = environmentFile;
      User = user;
    };
    script = "${pretalx}/bin/pretalx clearsessions";
  };

  systemd.services.pretalx-runperiodic = {
    description = "Pretalx periodic tasks";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = environmentFile;
      User = user;
    };
    script = "${pretalx}/bin/pretalx runperiodic";
  };

  # About once a month
  systemd.timers.pretalx-clearsessions = mkTimer {
    description = "Clear pretalx sessions";
    unit = "pretalx-clearsessions.service";
    onCalendar = "monthly";
  };

  # Once every 5 minutes
  systemd.timers.pretalx-runperiodic = mkTimer {
    description = "Run pretalx tasks";
    unit = "pretalx-runperiodic.service";
    onCalendar = "*:0/5";
  };

}
