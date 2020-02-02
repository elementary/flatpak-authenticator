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

public class FlatpakAuthenticator.Webflow {

    public delegate void WebflowCallback (GLib.HashTable<string, string>? query, GLib.Error error);

    public class WebflowData {
        public Soup.Server server;
        public string state;
        public bool started_webflow = false;
        public bool done = false;
        public WebflowCallback callback;
        public AuthenticatorRequest request;

        public WebflowData () {
            state = "";
            for (int i = 0; i < 4; i++) {
                state += "%0x".printf (Random.next_int ());
            }
        }
    }

    public static WebflowData start (AuthenticatorRequest request, string sender, Soup.URI? base_uri, string uri, owned WebflowCallback cb) {
        var data = new WebflowData ();
        data.server = new Soup.Server (Soup.SERVER_SERVER_HEADER, "flatpak-authenticator ");
        data.callback = (owned)cb;
        data.request = request;

        try {
            if (!data.server.listen_local (0, 0)) {
                finish_webflow (data, null, new IOError.FAILED ("Unable to setup server to listen for webflow response"));
            }
        } catch (Error e) {
            finish_webflow (data, null, e);
        }

        var listening_uris = data.server.get_uris ();
        if (listening_uris == null || listening_uris.length () == 0) {
            finish_webflow (data, null, new IOError.FAILED ("Unable to setup any listeners for webflow response"));
        }

        data.server.add_handler (null, (server, msg, path, query, client) => server_handler (server, msg, path, query, client, data));

        var redirect_uri = new Soup.URI.with_base (listening_uris.data, "/done");
        var redirect_uri_s = redirect_uri.to_string (false);
        debug ("redirect_uri = %s", redirect_uri_s);

        var webflow_uri = new Soup.URI.with_base (base_uri, uri);
        webflow_uri.set_query_from_fields ("redirect_uri", redirect_uri_s, "state", data.state);
        var webflow_uri_s = webflow_uri.to_string (false);

        debug ("webflow_uri = %s", webflow_uri_s);

        data.started_webflow = true;

        Idle.add (() => {
            request.webflow (webflow_uri_s, new GLib.HashTable<string, GLib.Variant?> (null, null));

            return false;
        });

        return data;
    }

    private static void finish_webflow (WebflowData data, GLib.HashTable<string, string>? query, GLib.Error? error) {
        if (data.done) {
            return;
        }

        data.done = true;

        if (data.started_webflow) {
            Idle.add (() => {
                data.request.webflow_done (new GLib.HashTable<string, GLib.Variant?> (null, null));

                return false;
            });

            data.started_webflow = false;
        }

        data.callback (query, error);
    }

    public static void cancel (WebflowData webflow) {
        debug ("cancelling webflow");
        finish_webflow (webflow, null, new IOError.CANCELLED ("User cancelled operation"));
    }

    private static void server_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable<string, string>? query, Soup.ClientContext client, WebflowData data) {
        debug ("Webflow server: incoming request \"%s %s\"", msg.method, path);

        if (msg.method != "HEAD" && msg.method != "GET") {
            msg.set_status (Soup.Status.NOT_IMPLEMENTED);

            return;
        }

        if (path != "/done") {
            msg.set_status (Soup.Status.NOT_FOUND);

            return;
        }

        string? state = null, redirect_uri = null;
        if (query != null) {
            state = query.lookup ("state");
            redirect_uri = query.lookup ("redirect_uri");
        }

        if (state == null || state != data.state) {
            const string html_error = "<html><body>Invalid state</body></html>";

            msg.set_status (Soup.Status.BAD_REQUEST);
            msg.set_response ("text/html", Soup.MemoryUse.STATIC, html_error.data);

            return;
        }

        const string html = "<html><body>Webflow done</body></html>";
        msg.set_response ("text/html", Soup.MemoryUse.STATIC, html.data);

        if (redirect_uri != null) {
            msg.set_redirect (Soup.Status.FOUND, redirect_uri);
        } else {
            msg.set_status (Soup.Status.OK);
        }

        finish_webflow (data, query, null);
    }
}
