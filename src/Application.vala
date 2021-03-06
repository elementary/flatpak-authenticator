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

public class FlatpakAuthenticator.Application : Gtk.Application {
    public Application () {
        Object (
            application_id: "io.elementary.flatpak_authenticator",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate () {
        StoredTokens.get_default ().load_tokens ();
        AuthServices.get_default ().load_services ();

        var authenticator = new Authenticator ();

        Bus.own_name (BusType.SESSION, "io.elementary.FlatpakAuthenticator", BusNameOwnerFlags.NONE, (connection) => {
            try {
                connection.register_object ("/org/freedesktop/Flatpak/Authenticator", authenticator);
                authenticator.set_connection (connection);
            } catch (Error e) {
                warning ("Registering flatpak authenticator failed: %s", e.message);
                quit ();
            }
        },
        () => {},
        (con, name) => {
            warning ("Could not aquire bus %s", name);
            quit ();
        });

        var manager = new Ag.Manager ();
        var accounts = manager.list ();
        foreach (var id in accounts) {
            get_account_data (manager.get_account (id));
        }

        hold ();
    }

    public async void get_account_data (Ag.Account account) {
        var account_service = new Ag.AccountService (account, null);
        var auth_data = account_service.get_auth_data ();
        var identity = new Signon.Identity.from_db (auth_data.get_credentials_id ());
        try {
            var info = yield identity.query_info (null);
            var methods = info.get_methods ();
        } catch (Error e) {
            critical (e.message);
        }
        /*var session = yield identity.create_session (string method);
        async Variant process (Variant session_data, string mechanism, Cancellable? cancellable)*/
    }

    public static int main (string[] args) {
        var app = new Application ();
        return app.run (args);
    }
}

