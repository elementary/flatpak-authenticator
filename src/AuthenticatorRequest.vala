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

public class FlatpakAuthenticator.RequestRefTokensData : GLib.Object {
    public string sender { get; set; }
    public Soup.URI? uri { get; set; }
    public string remote { get; set; }
    public GLib.HashTable<string, GLib.Variant?> authenticator_options { get; set; }
    public Gee.HashSet<string> unresolved_tokens { get; set; }
    public Gee.HashMap<string, Gee.ArrayList<string>> resolved_tokens { get; set; }
    public Gee.ArrayList<string> denied_tokens { get; set; }
    public int[] token_types;
    public string[] refs { get; set; }
}

public enum FlatpakAuthenticator.FlatpakAuthResponse {
    OK,
    CANCELLED,
    ERROR
}

[DBus (name = "org.freedesktop.Flatpak.AuthenticatorRequest")]
public class FlatpakAuthenticator.AuthenticatorRequest : GLib.Object {
        [DBus (visible = false)]
        public RequestRefTokensData request_data { get; construct; }

        private Soup.Session soup_session;
        private ElementaryAccount.AccountManager elementary_account;

        public AuthenticatorRequest (RequestRefTokensData data) {
            Object (request_data: data);
        }

        construct {
            soup_session = Utils.create_soup_session ("io.elementary.flatpak-authenticator");
            elementary_account = new ElementaryAccount.AccountManager ();

            var stored_tokens = StoredTokens.get_default ();
            var found_tokens = new Gee.HashMap<string, string> ();

            foreach (var id in request_data.unresolved_tokens) {
                var stored_token = stored_tokens.lookup_app_token (request_data.remote, id);
                if (stored_token != null) {
                    found_tokens[id] = stored_token;
                }
            }

            foreach (var item in found_tokens.entries) {
                resolve_id (item.key, item.value);
            }

            if (request_data.unresolved_tokens.size == 0) {
                check_done ();
            } else {
                start_api_flow.begin ();
            }
        }

        private void cancel_request () {
            var response_data = new GLib.HashTable<string, GLib.Variant?> (GLib.str_hash, GLib.str_equal);
            Idle.add (() => {
                response (FlatpakAuthResponse.CANCELLED, response_data);
                return false;
            });
        }

        private async void start_api_flow () {
            var logged_in = yield elementary_account.check_authenticated ();

            if (!logged_in) {
                var login_dialog = new LoginDialog (elementary_account);
                login_dialog.run ();
                login_dialog.finished.connect (get_unresolved_tokens);
            } else {
                get_unresolved_tokens ();
            }
        }

        private void get_unresolved_tokens () {
            if (request_data.unresolved_tokens.size == 0) {
                check_done ();

                return;
            }

            var apps = elementary_account.get_purchased_apps (request_data.unresolved_tokens.to_array ());
            get_tokens_cb (apps);
        }

        private void get_tokens_cb (Json.Node json) {
            var root = json.get_object ();

            if (root.has_member ("tokens")) {
                var tokens_dict = root.get_object_member ("tokens");
                var members = tokens_dict.get_members ();
                foreach (var id in members) {
                    var member = tokens_dict.get_member (id);
                    var token = member.get_string ();
                    if (token == null) {
                        token = "";
                    }

                    resolve_id (id, token);

                    StoredTokens.get_default ().update_download_token (request_data.remote, id, token);
                    StoredTokens.get_default ().save_tokens ();
                }
            }

            if (root.has_member ("denied")) {
                var denied_array = root.get_array_member ("denied");
                var len = denied_array.get_length ();
                for (int i = 0; i < len; i++) {
                    var denied_id = denied_array.get_string_element (i);
                    request_data.denied_tokens.add (denied_id);

                    warning ("Added denied_token %s", denied_id);
                }
            }

            check_done ();
        }

        private void resolve_id (string id, string token) {
            var refs_for_token = request_data.resolved_tokens[token];
            if (refs_for_token == null) {
                refs_for_token = new Gee.ArrayList<string> ();
                request_data.resolved_tokens[token] = refs_for_token;
            }

            foreach (var @ref in request_data.refs) {
                var id_for_ref = Utils.get_id_from_ref (@ref);

                if (id == id_for_ref) {
                    refs_for_token.add (@ref);
                }
            }

            request_data.unresolved_tokens.remove (id);
        }

        private Json.Node? verify_api_call_json_response (Soup.Message msg) {
            var response_data = new GLib.HashTable<string, GLib.Variant?> (GLib.str_hash, GLib.str_equal);

            if (msg.status_code != 200) {
                response_data["error-message"] = "API call failed, service returned status %u".printf (msg.status_code);
                response (FlatpakAuthResponse.ERROR, response_data);

                return null;
            }

            Json.Node? json = null;
            try {
                json = Json.from_string ((string)msg.response_body.data);
            } catch (Error e) {
                response_data["error-message"] = "Invalid JSON in service reply";
                response (FlatpakAuthResponse.ERROR, response_data);

                return null;
            }

            if (json == null || json.get_object () == null) {
                response_data["error-message"] = "Invalid JSON in service reply";
                response (FlatpakAuthResponse.ERROR, response_data);

                return null;
            }

            return json;
        }

        private void check_done () {
            warning ("denied_tokens %d", request_data.denied_tokens.size);
            warning ("unresolved_tokens %d", request_data.unresolved_tokens.size);

            if (request_data.denied_tokens.size > 0) {
                // Begin purchase
                var id = request_data.denied_tokens[0];

                var json = new Json.Object ();
                json.set_string_member ("id", id);

                warning ("Requesting details for id: %s", id);

                var api_url = new Soup.URI.with_base (request_data.uri, "api/v1/app/%s".printf (id));
                warning (api_url.to_string (false));
                var msg = new Soup.Message.from_uri ("GET", api_url);

                soup_session.queue_message (msg, app_details_cb);

            } else {
                var response_data = new GLib.HashTable<string, GLib.Variant?> (GLib.str_hash, GLib.str_equal);

                var builder = new VariantBuilder (new VariantType ("a{sas}"));
                foreach (var entry in request_data.resolved_tokens.entries) {
                    builder.add ("{s^as}", entry.key, entry.value.to_array ());
                }

                response_data["tokens"] = builder.end ();

                Idle.add (() => {
                    response (FlatpakAuthResponse.OK, response_data);

                    return false;
                });
            }
        }

        private void app_details_cb (Soup.Session session, Soup.Message msg) {
            warning ("API: Got get_application response, status code=%u", msg.status_code);

            var json = verify_api_call_json_response (msg);
            if (json == null) {
                return;
            }

            var root = json.get_object ();

            if (!root.has_member ("id")) {
                var response_data = new GLib.HashTable<string, GLib.Variant?> (GLib.str_hash, GLib.str_equal);
                response_data["error-message"] = "Could not find details about app from API";
                Idle.add (() => {
                    response (FlatpakAuthResponse.ERROR, response_data);
                    return false;
                });
            }

            var id = root.get_string_member ("id");
            var stripe_key = root.get_string_member ("stripe_key");
            var app_name = root.get_string_member ("name");
            var amount = root.get_int_member ("recommended_amount");

            var purchase_dialog = new Dialogs.PurchaseDialog (elementary_account, (int)amount, app_name, id, stripe_key);
            purchase_dialog.download_requested.connect ((token, store) => {
                purchase_dialog.destroy ();

                resolve_id (id, token);
                StoredTokens.get_default ().update_download_token (request_data.remote, id, token);
                StoredTokens.get_default ().save_tokens ();

                request_data.denied_tokens.remove_at (0);
                get_unresolved_tokens ();
            });

            purchase_dialog.cancelled.connect (() => {
                cancel_request ();
            });

            var response_code = purchase_dialog.run ();
            if (response_code == Gtk.ResponseType.NONE || response_code == Gtk.ResponseType.DELETE_EVENT) {
                cancel_request ();
            }
        }

        public void close () throws GLib.Error {
            warning ("handling request.Close %s", request_data.remote);

            // TODO: Should probably close any open dialogs here
        }

        public signal void webflow (string uri, GLib.HashTable<string, GLib.Variant?> options);
        public signal void webflow_done (GLib.HashTable<string, GLib.Variant?> options);
        public signal void basic_auth (string realm, GLib.HashTable<string, GLib.Variant?> options);
        public signal void response (uint response, GLib.HashTable<string, GLib.Variant?> results);

        public void basic_auth_reply (string user, string password, GLib.HashTable<string, GLib.Variant?> options) throws GLib.Error {
        }
}
