/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: David Hewitt <davidmhewitt@gmail.com>
*/

public class FlatpakAuthenticator.AuthServices {
    public class AuthService {
        public string remote;
        public string? token;
        public DateTime valid_until;

        private static Regex regex;

        static construct {
            try {
                regex = new Regex ("^remote \"(.+)\"$");
            } catch (Error e) {
                critical ("Error constructing regex, should be unreachable");
            }
        }

        public AuthService.for_name (string name) {
            remote = name;
        }

        public AuthService.for_group (KeyFile keyfile, string group) throws GLib.Error {
            assert (regex != null);
            assert (keyfile.has_group (group));

            MatchInfo match;
            if (!regex.match (group, 0, out match)) {
                throw new IOError.FAILED ("AuthService group does not match regex");
            }

            remote = match.fetch (1);
            parse (keyfile, group);
        }

        public void parse (KeyFile keyfile, string group) throws GLib.Error {
            token = keyfile.get_string (group, "token");
        }
    }

    private GLib.HashTable<string, AuthService> services;

    private static AuthServices? _instance = null;
    public static AuthServices get_default () {
        if (_instance == null) {
            _instance = new AuthServices ();
        }

        return _instance;
    }

    private static string get_config_file () {
        return Path.build_filename (Environment.get_user_config_dir (), "flatpak", "auth-services.conf");
    }

    public void load_services () {
        var path = get_config_file ();
        var keyfile = new KeyFile ();

        try {
            keyfile.load_from_file (path, KeyFileFlags.NONE);
        } catch (Error e) {
            if (!(e is FileError.NOENT)) {
                warning ("Unable to read service data %s: %s", path, e.message);
            }
        }

        services = new GLib.HashTable<string, AuthService> (str_hash, str_equal);
        var groups = keyfile.get_groups ();

        foreach (var group in groups) {
            try {
                var service = new AuthService.for_group (keyfile, group);
                services[service.remote] = service;
            } catch (Error e) {
                warning ("Unable to read an auth service from config: %s", e.message);
            }
        }
    }

    public AuthService lookup_service (string remote) {
        var service = services[remote];
        if (service == null) {
            service = new AuthService.for_name (remote);
            services[remote] = service;
        }

        return service;
    }

    public string? lookup_service_token (string remote) {
        return lookup_service (remote).token;
    }

    public void update_service_token (string remote, string? token) {
        debug ("Updating token for remote %s", remote);

        var service = lookup_service (remote);

        service.token = token;

        save_services ();
    }

    public void save_services () {
        var path = get_config_file ();
        var path_dir = Path.get_dirname (path);

        var keyfile = new KeyFile ();
        var keys = services.get_keys ();
        keys.sort (strcmp);

        foreach (var key in keys) {
            var remote = (string)key.data;
            var service = services.lookup (remote);

            var group = "remote \"%s\"".printf (remote);
            if (service.token != null) {
                keyfile.set_string (group, "token", service.token);
            }
        }

        DirUtils.create_with_parents (path_dir, 0777);
        try {
            keyfile.save_to_file (path);
        } catch (Error e) {
            warning ("Unable to save tokens to keyfile: %s", e.message);
        }
    }
}
