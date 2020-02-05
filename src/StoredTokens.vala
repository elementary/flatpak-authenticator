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

public class FlatpakAuthenticator.StoredTokens {
    public class Token {
        public string remote;
        public string app_id;
        public string? token;

        private static Regex regex;

        static construct {
            try {
                regex = new Regex ("^\"(.+)\" from remote \"(.+)\"$");
            } catch (Error e) {
                critical ("Error constructing regex, should be unreachable");
            }
        }

        public Token.for_remote_and_id (string remote, string id) {
            this.remote = remote;
            app_id = id;
        }

        public Token.for_group (KeyFile keyfile, string group) throws GLib.Error {
            assert (regex != null);
            assert (keyfile.has_group (group));

            MatchInfo match;
            if (!regex.match (group, 0, out match)) {
                throw new IOError.FAILED ("Token group does not match regex");
            }

            app_id = match.fetch (1);
            remote = match.fetch (2);
            parse (keyfile, group);
        }

        public void parse (KeyFile keyfile, string group) throws GLib.Error {
            token = keyfile.get_string (group, "token");
        }
    }

    private GLib.HashTable<string, Token> tokens;

    private static StoredTokens? _instance = null;
    public static StoredTokens get_default () {
        if (_instance == null) {
            _instance = new StoredTokens ();
        }

        return _instance;
    }

    private static string get_config_file () {
        return Path.build_filename (Environment.get_user_config_dir (), "flatpak", "stored-tokens.conf");
    }

    public void load_tokens () {
        var path = get_config_file ();
        var keyfile = new KeyFile ();

        try {
            keyfile.load_from_file (path, KeyFileFlags.NONE);
        } catch (Error e) {
            if (!(e is FileError.NOENT)) {
                warning ("Unable to read token data %s: %s", path, e.message);
            }
        }

        tokens = new GLib.HashTable<string, Token> (str_hash, str_equal);
        var groups = keyfile.get_groups ();

        foreach (var group in groups) {
            try {
                var token = new Token.for_group (keyfile, group);
                tokens[token.remote + "/" + token.app_id] = token;
            } catch (Error e) {
                warning ("Unable to read an token from stored tokens: %s", e.message);
            }
        }
    }

    public Token lookup_token (string remote, string app_id) {
        var token = tokens[remote + "/" + app_id];
        if (token == null) {
            token = new Token.for_remote_and_id (remote, app_id);
            tokens[remote + "/" + app_id] = token;
        }

        return token;
    }

    public string? lookup_app_token (string remote, string app_id) {
        return lookup_token (remote, app_id).token;
    }

    public void update_download_token (string remote, string app_id, string token) {
        debug ("Updating download token for app_id %s on remote %s", app_id, remote);

        var service = lookup_token (remote, app_id);

        service.token = token;

        save_tokens ();
    }

    public void save_tokens () {
        var path = get_config_file ();
        var path_dir = Path.get_dirname (path);

        var keyfile = new KeyFile ();
        var keys = tokens.get_keys ();
        keys.sort (strcmp);

        foreach (var key in keys) {
            var key_s = (string)key.data;
            var token = tokens.lookup (key_s);

            var group = "\"%s\" from remote \"%s\"".printf (token.app_id, token.remote);
            if (token.token != null) {
                keyfile.set_string (group, "token", token.token);
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
