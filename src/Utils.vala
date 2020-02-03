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

namespace FlatpakAuthenticator.Utils {
    public const string FLATPAK_AUTHENTICATOR_REQUEST_OBJECT_PATH_PREFIX = "/org/freedesktop/Flatpak/Authenticator/request/";

    public static string? create_request_path (string peer, string token) throws GLib.Error {
        for (int i = 0; i < token.length; i++) {
            if (!token[i].isalnum () && token[i] != '_') {
                throw new GLib.IOError.FAILED ("Invalid token %s", token);
            }
        }

        string escaped_peer = peer.replace (".", "_").substring (1);
        return FLATPAK_AUTHENTICATOR_REQUEST_OBJECT_PATH_PREFIX.concat (escaped_peer, "/", token);
    }

    public static string get_id_from_ref (string @ref) {
        var parts = @ref.split ("/");
        if (parts.length != 4) {
            return "none";
        }

        var id = parts[1];
        if (flatpak_id_has_subref_suffix (id)) {
            id = id.substring (0, id.last_index_of_char ('.'));
        }

        return id;
    }

    public static bool flatpak_id_has_subref_suffix (string id) {
        return id.has_suffix (".Locale") || id.has_suffix (".Debug") || id.has_suffix (".Sources");
    }

    public static Soup.Session create_soup_session (string user_agent) {
        var soup_session = new Soup.Session.with_options (
            Soup.SESSION_USER_AGENT, user_agent,
            Soup.SESSION_SSL_USE_SYSTEM_CA_FILE, true,
            Soup.SESSION_USE_THREAD_CONTEXT, true,
            Soup.SESSION_TIMEOUT, 60,
            Soup.SESSION_IDLE_TIMEOUT, 60
        );

        soup_session.remove_feature_by_type (typeof (Soup.ContentDecoder));

        var http_proxy = Environment.get_variable ("http_proxy");
        if (http_proxy != null) {
            var proxy_uri = new Soup.URI (http_proxy);
            if (proxy_uri == null) {
                warning ("Invalid proxy URI '%s'", http_proxy);
            } else {
                soup_session.@set (Soup.SESSION_PROXY_URI, proxy_uri);
            }
        }

        return soup_session;
    }
}
