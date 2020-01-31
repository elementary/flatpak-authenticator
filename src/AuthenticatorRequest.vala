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

[DBus (name = "org.freedesktop.Flatpak.AuthenticatorRequest")]
public class FlatpakAuthenticator.AuthenticatorRequest : GLib.Object {
        public void close () throws GLib.Error {
        }

        public signal void webflow (string uri, GLib.HashTable<string, GLib.Variant?> options);
        public signal void webflow_done (GLib.HashTable<string, GLib.Variant?> options);
        public signal void basic_auth (string realm, GLib.HashTable<string, GLib.Variant?> options);
        public signal void response (uint response, GLib.HashTable<string, GLib.Variant?> results);

        public void basic_auth_reply (string user, string password, GLib.HashTable<string, GLib.Variant?> options) throws GLib.Error {
        }
}
