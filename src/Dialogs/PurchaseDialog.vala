/*
* Copyright (c) 2016-2017 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
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
*/

public class FlatpakAuthenticator.Dialogs.PurchaseDialog : Gtk.Dialog {
    public signal void download_requested (int amount);
    public signal void cancelled ();

    private Gtk.Grid? payment_layout = null;
    private Gtk.Stack layouts;

    private Widgets.PaymentMethodButton new_payment_method;
    private Gtk.Label primary_label;
    private Gtk.Button cancel_button;

    public ElementaryAccount.AccountManager elementary_account { get; construct; }
    public int amount { get; construct set; }
    public string app_name { get; construct set; }
    public string app_id { get; construct set; }

    private ElementaryAccount.Card? selected_payment_method = null;
    private string? anon_id = null;

    public PurchaseDialog (ElementaryAccount.AccountManager account, int _amount, string _app_name, string _app_id) {
        Object (
            amount: _amount,
            app_name: _app_name,
            app_id: _app_id,
            deletable: false,
            resizable: false,
            title: _("Payment"),
            elementary_account: account
        );
    }

    construct {
        var image = new Gtk.Image.from_icon_name ("payment-card", Gtk.IconSize.DIALOG);
        image.valign = Gtk.Align.START;

        var overlay_image = new Gtk.Image.from_icon_name ("system-software-install", Gtk.IconSize.LARGE_TOOLBAR);
        overlay_image.halign = overlay_image.valign = Gtk.Align.END;

        var overlay = new Gtk.Overlay ();
        overlay.valign = Gtk.Align.START;
        overlay.add (image);
        overlay.add_overlay (overlay_image);

        primary_label = new Gtk.Label (_("Pay $%d for %s").printf (amount, app_name));
        primary_label.get_style_context ().add_class ("primary");
        primary_label.xalign = 0;

        var secondary_label = new Gtk.Label (_("This is a one time payment. Your email address is only used to send you a receipt."));
        secondary_label.margin_bottom = 18;
        secondary_label.max_width_chars = 50;
        secondary_label.wrap = true;
        secondary_label.xalign = 0;

        var payment_methods = new Gtk.Grid ();
        payment_methods.orientation = Gtk.Orientation.VERTICAL;

        new_payment_method = new Widgets.PaymentMethodButton (null, false);
        new_payment_method.selected.connect ((card) => {
            selected_payment_method = card;
        });

        if (elementary_account.logged_in) {
            foreach (var card in elementary_account.get_cards ()) {
                var method = new Widgets.PaymentMethodButton (card, true);
                method.selected.connect ((card) => {
                    selected_payment_method = card;
                });

                method.radio.join_group (new_payment_method.radio);
                payment_methods.add (method);
            }
        } else {
            anon_id = ElementaryAccount.Utils.base64_url_encode (ElementaryAccount.Utils.generate_random_bytes (32));
        }

        payment_methods.add (new_payment_method);

        var card_layout = new Gtk.Grid ();
        card_layout.get_style_context ().add_class ("login");
        card_layout.column_spacing = 12;
        card_layout.row_spacing = 6;
        card_layout.attach (overlay, 0, 0, 1, 2);
        card_layout.attach (primary_label, 1, 0);
        card_layout.attach (secondary_label, 1, 1);
        card_layout.attach (payment_methods, 1, 3);

        layouts = new Gtk.Stack ();
        layouts.vhomogeneous = false;
        layouts.margin_start = layouts.margin_end = 12;
        layouts.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        layouts.add_named (card_layout, "card");
        layouts.set_visible_child_name ("card");

        var content_area = get_content_area ();
        content_area.add (layouts);
        content_area.show_all ();

        var privacy_policy_link = new Gtk.LinkButton.with_label ("https://stripe.com/privacy", _("Privacy Policy"));
        privacy_policy_link.show ();

        var action_area = (Gtk.ButtonBox) get_action_area ();
        action_area.margin = 5;
        action_area.margin_top = 14;
        action_area.add (privacy_policy_link);
        action_area.set_child_secondary (privacy_policy_link, true);

        cancel_button = (Gtk.Button) add_button (_("Cancel"), Gtk.ResponseType.CLOSE);

        var humble_button = new Widgets.HumbleButton ();
        humble_button.amount = amount;
        humble_button.allow_free = true;
        humble_button.can_purchase = true;
        humble_button.show_all ();
        humble_button.notify["amount"].connect (() => {
            amount = humble_button.amount;
            primary_label.label = _("Pay $%d for %s").printf (amount, app_name);
        });

        humble_button.payment_requested.connect ((requested_amount) => {
            amount = requested_amount;

            if (amount == 0) {
                download_requested (0);
            } else {
                show_payment_intent_view ();
            }
        });

        (get_action_area () as Gtk.Box).pack_end (humble_button);

        response.connect (on_response);
    }

    private void show_payment_intent_view () {
        if (payment_layout == null) {
            payment_layout = new Gtk.Grid ();

            var webview = new ElementaryAccount.NativeWebView ();
            webview.success.connect (() => {
                download_requested (amount);
            });

            webview.close.connect (() => {
                cancel_button.activate ();
            });

            webview.height_request = 300;

            var payment_uri = new Soup.URI (ElementaryAccount.Utils.get_api_uri ("/intents/do_charge"));

            var args = new GLib.HashTable<string, string>(str_hash, str_equal);
            args.insert ("amount", (amount * 100).to_string ());
            args.insert ("app_id", app_id);

            if (selected_payment_method != null) {
                args.insert ("payment_method", selected_payment_method.stripe_id);
            }

            if (anon_id != null) {
                args.insert ("anon_id", anon_id);
            }

            payment_uri.set_query_from_form (args);

            var payment_url = payment_uri.to_string (false);
            if (elementary_account.account_token != null) {
                webview.get_with_bearer (payment_url, elementary_account.account_token);
            } else {
                webview.load_uri (payment_url);
            }

            payment_layout.add (webview);

            layouts.add_named (payment_layout, "payment");
            layouts.show_all ();
        }

        layouts.set_visible_child_name ("payment");
        // Webview has its own buttons
        get_action_area ().visible = false;
    }

    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.CLOSE:
                cancelled ();
                destroy ();

                break;
        }
    }
}


