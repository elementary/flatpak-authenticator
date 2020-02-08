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

    public string? token;
    public Webflow.WebflowData webflow;
}

public enum FlatpakAuthenticator.FlatpakAuthResponse {
    OK,
    CANCELLED,
    ERROR
}

[DBus (name = "org.freedesktop.Flatpak.AuthenticatorRequest")]
public class FlatpakAuthenticator.AuthenticatorRequest : GLib.Object {
        private const string LOGIN_ENDPOINT = "/login";

        [DBus (visible = false)]
        public RequestRefTokensData request_data { get; construct; }

        private Soup.Session soup_session;

        public AuthenticatorRequest (RequestRefTokensData data) {
            Object (request_data: data);
        }

        construct {
            soup_session = Utils.create_soup_session ("io.elementary.flatpak-authenticator");

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
                start_api_flow ();
            }
        }

        private void start_api_flow (string? error = null) {
            var auth_services = AuthServices.get_default ();
            request_data.token = auth_services.lookup_service_token (request_data.remote);
            if (request_data.token == null) {
                var login_dialog = new LoginDialog (error);
                login_dialog.login.connect (on_login);
                login_dialog.skip.connect (get_unresolved_tokens);
                var response_code = login_dialog.run ();
                login_dialog.destroy ();

                if (response_code == Gtk.ResponseType.CANCEL) {
                    var response_data = new GLib.HashTable<string, GLib.Variant?> (GLib.str_hash, GLib.str_equal);
                    Idle.add (() => {
                        response (FlatpakAuthResponse.CANCELLED, response_data);
                        return false;
                    });
                }
            } else {
                get_unresolved_tokens ();
            }
        }

        private void on_login (string username, string password) {
            var json = new Json.Object ();
            json.set_string_member ("username", username);
            json.set_string_member ("password", password);

            var msg = create_api_call (request_data.uri, LOGIN_ENDPOINT, null, json);
            soup_session.queue_message (msg, login_cb);
        }

        private void login_cb (Soup.Session session, Soup.Message message) {
            debug ("Login uri: %s", message.uri.to_string (false));
            debug ("API: got login response, status code=%u", message.status_code);

            var json = verify_api_call_json_response (message);
            if (json == null) {
                return;
            }

            var root = json.get_object ();
            if (root.has_member ("access_token")) {
                var token = root.get_string_member ("access_token");
                AuthServices.get_default ().update_service_token (request_data.remote, token);

                get_unresolved_tokens ();
            }
        }

        private void get_unresolved_tokens () {
            if (request_data.unresolved_tokens.size == 0) {
                check_done ();

                return;
            }

            var ids_str = "";

            var json = new Json.Object ();
            var ids_array = new Json.Array ();

            json.set_array_member ("ids", ids_array);

            foreach (var token in request_data.unresolved_tokens) {
                ids_array.add_string_element (token);
                if (ids_str.length > 0) {
                    ids_str += ", ";
                }

                ids_str += token;
            }

            debug ("API: Requesting tokens for ids: %s", ids_str);

            var msg = create_api_call (request_data.uri, "api/v1/get_tokens", request_data.token, json);
            soup_session.queue_message (msg, get_tokens_cb);
        }

        private void get_tokens_cb (Soup.Session session, Soup.Message message) {
            debug ("API: got tokens response, status code=%u", message.status_code);

            var json = verify_api_call_json_response (message);
            if (json == null) {
                return;
            }

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

                    debug ("Added denied_token %s", denied_id);
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

            if (msg.status_code == 401) {
                if (msg.uri.get_path () == LOGIN_ENDPOINT) {
                    start_api_flow (_("Incorrect credentials. Please try again."));
                // Our token has probably expired
                } else {
                    AuthServices.get_default ().update_service_token (request_data.remote, null);
                    start_api_flow (_("Session expired. Please log in again"));
                }

                return null;
            }

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

        private Soup.Message create_api_call (Soup.URI base_uri, string api_path, string? token, Json.Object json) {
            var root = new Json.Node.alloc ();
            root.init_object (json);
            var body = Json.to_string (root, false);

            var api_url = new Soup.URI.with_base (base_uri, api_path);

            var msg = new Soup.Message.from_uri ("POST", api_url);
            msg.set_request ("application/json", Soup.MemoryUse.COPY, body.data);

            if (token != null) {
                var bearer = "Bearer %s".printf (token);
                msg.request_headers.append ("Authorization", bearer);
            }

            return msg;
        }

        private void check_done () {
            debug ("denied_tokens %d", request_data.denied_tokens.size);
            debug ("unresolved_tokens %d", request_data.unresolved_tokens.size);

            if (request_data.denied_tokens.size > 0) {
                // Begin purchase
                var id = request_data.denied_tokens[0];

                // TODO: Fetch amount, name, and stripe token
                var purchase_dialog = new Dialogs.StripeDialog (5, "Prototype", id, "fake_token");
                var response_code = purchase_dialog.run ();
                purchase_dialog.destroy ();

                var json = new Json.Object ();
                json.set_string_member ("id", id);

                debug ("Requesting purchase of id: %s", id);

                var msg = create_api_call (request_data.uri, "api/v1/begin_purchase", request_data.token, json);
                soup_session.queue_message (msg, begin_purchase_cb);
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

        private void begin_purchase_cb (Soup.Session session, Soup.Message msg) {
            debug ("API: Got begin_purchase response, status code=%u", msg.status_code);

            var json = verify_api_call_json_response (msg);
            if (json == null) {
                return;
            }

            request_data.denied_tokens.remove_at (0);

            var root = json.get_object ();

            if (root.has_member ("shortTokens")) {
                var tokens_dict = root.get_object_member ("shortTokens");
                var members = tokens_dict.get_members ();
                foreach (var id in members) {
                    var member = tokens_dict.get_member (id);
                    var token = member.get_string ();
                    if (token == null) {
                        token = "";
                    }

                    resolve_id (id, token);
                }
            }

            if (root.has_member ("longTokens")) {
                var tokens_dict = root.get_object_member ("longTokens");
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

            get_unresolved_tokens ();
        }

        public void close () throws GLib.Error {
            debug ("handling request.Close %s", request_data.remote);

            if (request_data.webflow != null) {
                Webflow.cancel (request_data.webflow);
            }
        }

        public signal void webflow (string uri, GLib.HashTable<string, GLib.Variant?> options);
        public signal void webflow_done (GLib.HashTable<string, GLib.Variant?> options);
        public signal void basic_auth (string realm, GLib.HashTable<string, GLib.Variant?> options);
        public signal void response (uint response, GLib.HashTable<string, GLib.Variant?> results);

        public void basic_auth_reply (string user, string password, GLib.HashTable<string, GLib.Variant?> options) throws GLib.Error {
        }
}
