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

[DBus (name = "org.freedesktop.Flatpak.Authenticator")]
public class FlatpakAuthenticator.Authenticator : GLib.Object {
    public struct AuthenticatorRefStruct {
        public string @ref;
        public string commit;
        public int token_type;
        public GLib.HashTable<string, GLib.Variant?> metadata;
    }

    public uint version { get; set; default = 1; }

    private GLib.DBusConnection? connection = null;

    public Authenticator () {
    }

    public DBus.ObjectPath request_ref_tokens (
        string handle_token,
        GLib.HashTable<string, GLib.Variant?> authenticator_options,
        string remote,
        string remote_uri,
        AuthenticatorRefStruct[] refs,
        GLib.HashTable<string, GLib.Variant?> options,
        string parent_window,
        GLib.BusName sender
    ) throws GLib.Error {
        debug ("handling Authenticator.RequestRefTokens");

        if (!authenticator_options.contains ("url")) {
            throw new DBus.Error.INVALID_ARGS ("No url specified");
        }

        string request_path = Utils.create_request_path (sender, handle_token);
        if (request_path == null) {
            throw new DBus.Error.INVALID_ARGS ("Unable to construct request path");
        }

        if (connection == null) {
            throw new DBus.Error.FAILED ("DBus connection not available");
        }

        var request = new AuthenticatorRequest ();
        connection.register_object (request_path, request);

        return new DBus.ObjectPath (request_path);
    }

    [DBus (visible = false)]
    public void set_connection (GLib.DBusConnection connection) {
        this.connection = connection;
    }
}

