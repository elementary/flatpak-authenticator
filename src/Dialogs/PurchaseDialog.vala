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
    public signal void download_requested (string token, bool store);
    public signal void cancelled ();

    private Gtk.Grid? processing_layout = null;
    private Gtk.Stack layouts;

    private AppCenter.Widgets.PaymentMethodButton new_payment_method;
    private Gtk.Button pay_button;
    private Gtk.Button cancel_button;

    public ElementaryAccount.AccountManager elementary_account { get; construct; }
    public int amount { get; construct set; }
    public string app_name { get; construct set; }
    public string app_id { get; construct set; }
    public string stripe_key { get; construct set; }

    private bool email_valid = false;
    private bool card_valid = false;
    private bool expiration_valid = false;
    private bool cvc_valid = false;

    private string? returned_token = null;

    public PurchaseDialog (ElementaryAccount.AccountManager account, int _amount, string _app_name, string _app_id, string _stripe_key) {
        Object (
            amount: _amount,
            app_name: _app_name,
            app_id: _app_id,
            deletable: false,
            resizable: false,
            stripe_key: _stripe_key,
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

        var primary_label = new Gtk.Label (_("Pay $%d for %s").printf (amount, app_name));
        primary_label.get_style_context ().add_class ("primary");
        primary_label.xalign = 0;

        var secondary_label = new Gtk.Label (_("This is a one time payment. Your email address is only used to send you a receipt."));
        secondary_label.margin_bottom = 18;
        secondary_label.max_width_chars = 50;
        secondary_label.wrap = true;
        secondary_label.xalign = 0;

        var payment_methods = new Gtk.Grid ();
        payment_methods.orientation = Gtk.Orientation.VERTICAL;

        new_payment_method = new AppCenter.Widgets.PaymentMethodButton ("New Payment Method…");

        if (elementary_account.logged_in) {
            foreach (var card in elementary_account.get_cards ()) {
                var method = new AppCenter.Widgets.PaymentMethodButton ("%s %s".printf (card.title_case_brand, card.last_four), "payment-card-%s".printf (card.brand), true);
                method.radio.join_group (new_payment_method.radio);
                payment_methods.add (method);
            }
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

        pay_button = (Gtk.Button) add_button (_("Pay $%d.00").printf (amount), Gtk.ResponseType.APPLY);
        pay_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        pay_button.has_default = true;
        pay_button.sensitive = false;

        response.connect (on_response);
    }

    private void show_spinner_view () {
        if (processing_layout == null) {
            processing_layout = new Gtk.Grid ();
            processing_layout.orientation = Gtk.Orientation.VERTICAL;
            processing_layout.column_spacing = 12;

            var spinner = new Gtk.Spinner ();
            spinner.width_request = 48;
            spinner.height_request = 48;
            spinner.start ();

            var label = new Gtk.Label (_("Processing"));
            label.hexpand = true;
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.valign = Gtk.Align.CENTER;
            box.vexpand = true;

            box.add (spinner);
            box.add (label);
            processing_layout.add (box);

            layouts.add_named (processing_layout, "processing");
            layouts.show_all ();
        }

        layouts.set_visible_child_name ("processing");
        cancel_button.sensitive = false;
        pay_button.sensitive = false;
    }

    private void show_card_view () {
        pay_button.label = _("Pay $%d.00").printf (amount);
        cancel_button.label = _("Cancel");

        layouts.set_visible_child_name ("card");
    }

    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.APPLY:
                if (layouts.visible_child_name == "card") {
                    show_spinner_view ();
                } else {
                    show_card_view ();
                }
                break;
            case Gtk.ResponseType.CLOSE:
                if (layouts.visible_child_name == "error" && returned_token != null) {
                    download_requested (returned_token, false);
                } else {
                    cancelled ();
                    destroy ();
                }

                break;
        }
    }
}


