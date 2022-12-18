{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.permown;
in
{

  options.services.permown = mkOption {
    default = { };
    type = with types;
      attrsOf (submodule ({ config, ... }: {
        options = {
          directory-mode = mkOption {
            default = "=rwx";
            type = types.str;
            description = "permissions given to sub-directories";
          };
          file-mode = mkOption {
            default = "=rw";
            type = types.str;
            description = "permissions given to files";
          };
          owner = mkOption {
            type = types.str;
            description = "user which should own files and directories";
          };
          group = mkOption {
            apply = x: if x == null then "" else x;
            default = null;
            type = types.nullOr types.str;
            description = "group which should own files and directories";
          };
          keepGoing = mkOption {
            default = false;
            type = types.bool;
            description = ''
              Whether to keep going when chowning or chmodding fails.
              If set to false, then errors will cause the service to restart
              instead.
            '';
          };
          path = mkOption {
            default = config._module.args.name;
            type = types.path;
            description = "path of file/folder permown should managed permissions for";
          };
          umask = mkOption {
            default = "0027";
            type = types.str;
            description = "file mode creation mask.";
          };
        };
      }));
  };

  config =
    let
      plans = attrValues cfg;
    in
    mkIf (plans != [ ]) {
      system.activationScripts.permown =
        let
          mkdir = { path, ... }: ''
            ${pkgs.coreutils}/bin/mkdir -p "${path}"
          '';
        in
        concatMapStrings mkdir plans;

      systemd.services =
        let
          nameGenerator = { path, ... }:
            "permown.${replaceStrings [ "/" ] [ "_" ] path}";
          serviceDefinition =
            { path, directory-mode, file-mode, owner, group, umask, keepGoing, ... }:
            {
              environment = {
                DIR_MODE = directory-mode;
                FILE_MODE = file-mode;
                OWNER_GROUP = "${owner}:${group}";
                ROOT_PATH = path;
              };
              path = [
                pkgs.coreutils
                pkgs.findutils
                pkgs.inotifyTools
              ];
              serviceConfig = {
                ExecStart =
                  let
                    continuable = command:
                      if keepGoing
                      then "{ ${command}; } || :"
                      else command;
                  in
                  pkgs.writers.writeDash "permown" ''
                    set -efu

                    find "$ROOT_PATH" -exec chown -h "$OWNER_GROUP" {} +
                    find "$ROOT_PATH" -type d -exec chmod "$DIR_MODE" {} +
                    find "$ROOT_PATH" -type f -exec chmod "$FILE_MODE" {} +

                    paths=/tmp/paths
                    rm -f "$paths"
                    mkfifo "$paths"

                    inotifywait -mrq -e CREATE --format %w%f "$ROOT_PATH" > "$paths" &
                    inotifywaitpid=$!

                    trap cleanup EXIT
                    cleanup() {
                      kill "$inotifywaitpid"
                    }

                    while read -r path
                    do
                      if test -d "$path"; then
                        cleanup
                        exec "$0" "$@"
                      fi
                      ${continuable ''chown -h "$OWNER_GROUP" "$path"''}
                      if test -f "$path"; then
                        ${continuable ''chmod "$FILE_MODE" "$path"''}
                      fi
                    done < "$paths"
                  '';
                PrivateTmp = true;
                Restart = "always";
                RestartSec = 10;
                UMask = umask;
              };
              wantedBy = [ "multi-user.target" ];
            };
        in
        listToAttrs (map
          (plan:
            {
              name = nameGenerator plan;
              value = serviceDefinition plan;
            })
          plans);


    };

}
