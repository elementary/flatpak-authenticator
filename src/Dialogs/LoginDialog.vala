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

public class FlatpakAuthenticator.LoginDialog : Gtk.Dialog {

    public string? error_message { get; construct; }
    public ElementaryAccount.AccountManager account { get; construct; }

    public signal void finished ();

    private string verifier;

    public LoginDialog (ElementaryAccount.AccountManager account) {
        Object (account: account);
    }

    construct {
        var webview = new ElementaryAccount.NativeWebView ();

        verifier = ElementaryAccount.Utils.base64_url_encode (ElementaryAccount.Utils.generate_random_bytes (32));
        var challenge = ElementaryAccount.Utils.base64_url_encode (ElementaryAccount.Utils.sha256 (verifier.data));

        var constructed_uri = new Soup.URI (ElementaryAccount.Utils.get_api_uri ("/oauth/authorize"));
        constructed_uri.set_query_from_fields (
            "client_id", ElementaryAccount.Constants.CLIENT_ID,
            "scope", "profile",
            "response_type", "code",
            "redirect_uri", "urn:ietf:wg:oauth:2.0:oob",
            "code_challenge", challenge,
            "code_challenge_method", "S256"
        );

        webview.load_uri (constructed_uri.to_string (false));
        webview.success.connect (on_code_received);

        get_content_area ().add (webview);

        get_action_area ().margin = 5;

        show_all ();
    }

    private void on_code_received (string code) {
        account.exchange_code_for_token (ElementaryAccount.Utils.get_api_uri ("/oauth/token"), code, verifier);

        finished ();
    }
}

