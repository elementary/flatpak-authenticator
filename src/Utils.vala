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
}
