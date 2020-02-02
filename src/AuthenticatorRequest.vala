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
    public string[] denied_tokens { get; set; }
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
        [DBus (visible = false)]
        public RequestRefTokensData request_data { get; construct; }

        public AuthenticatorRequest (RequestRefTokensData data) {
            Object (request_data: data);
        }

        construct {
            var auth_services = AuthServices.get_default ();
            request_data.token = auth_services.lookup_service_token (request_data.remote);
            if (request_data.token == null) {
                request_data.webflow = Webflow.start (this, request_data.sender, request_data.uri, "login", (query, error) => {
                    var response_data = new GLib.HashTable<string, GLib.Variant?> (GLib.str_hash, GLib.str_equal);
                    if (error != null) {
                        debug ("webflow complete with errors");

                        if (error is IOError.CANCELLED) {
                            response (FlatpakAuthResponse.CANCELLED, response_data);
                        } else {
                            response_data["error-message"] = error.message;
                            response (FlatpakAuthResponse.ERROR, response_data);
                        }
                    } else {
                        debug ("webflow complete");

                        string? token = null;
                        if (query != null) {
                            token = query.lookup ("token");
                        }

                        if (token == null) {
                            response_data["error-message"] = "No token returned by server";
                            response (FlatpakAuthResponse.ERROR, response_data);
                        }

                        request_data.token = token;

                        debug ("Logged in, new token %s", token);

                        auth_services.update_service_token (request_data.remote, token);

                        get_unresolved_tokens ();
                    }
                });
            } else {
                get_unresolved_tokens ();
            }
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
