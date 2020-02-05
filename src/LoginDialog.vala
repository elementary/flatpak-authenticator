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
    private Gtk.Button login_button;
    private Gtk.Entry username_entry;
    private Gtk.Entry password_entry;

    public signal void login (string username, string password);

    construct {
        var image = new Gtk.Image.from_icon_name ("preferences-desktop-online-accounts", Gtk.IconSize.DIALOG);
        image.valign = Gtk.Align.START;

        var primary_label = new Gtk.Label (_("Login to elementary account"));
        primary_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);
        primary_label.xalign = 0;

        var secondary_label = new Gtk.Label (_("Applications you have purchased will be stored in your account"));
        secondary_label.margin_bottom = 18;
        secondary_label.max_width_chars = 50;
        secondary_label.wrap = true;
        secondary_label.xalign = 0;

        username_entry = new Gtk.Entry ();
        username_entry.activates_default = true;
        username_entry.hexpand = true;
        username_entry.placeholder_text = _("Username");
        username_entry.primary_icon_name = "system-users-symbolic";

        password_entry = new Gtk.Entry ();
        password_entry.activates_default = true;
        password_entry.hexpand = true;
        password_entry.visibility = false;
        password_entry.placeholder_text = _("Password");
        password_entry.primary_icon_name = "dialog-password-symbolic";

        var card_grid = new Gtk.Grid ();
        card_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        card_grid.orientation = Gtk.Orientation.VERTICAL;
        card_grid.add (username_entry);
        card_grid.add (password_entry);

        var card_layout = new Gtk.Grid ();
        card_layout.get_style_context ().add_class ("login");
        card_layout.column_spacing = 12;
        card_layout.row_spacing = 6;
        card_layout.margin = 10;
        card_layout.margin_top = 0;
        card_layout.attach (image, 0, 0, 1, 2);
        card_layout.attach (primary_label, 1, 0);
        card_layout.attach (secondary_label, 1, 1);
        card_layout.attach (card_grid, 1, 2);
        card_layout.show_all ();

        get_content_area ().add (card_layout);

        get_action_area ().margin = 5;

        add_button (_("Cancel"), Gtk.ResponseType.CLOSE);

        login_button = (Gtk.Button) add_button (_("Login"), Gtk.ResponseType.APPLY);
        login_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        login_button.has_default = true;
        login_button.sensitive = false;

        deletable = false;
        resizable = false;

        username_entry.changed.connect (() => {
            validate_form ();
        });

        password_entry.changed.connect (() => {
            validate_form ();
        });

        response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.APPLY) {
                login (username_entry.text, password_entry.text);
            }

            destroy ();
        });
    }

    private void validate_form () {
        login_button.sensitive = username_entry.text.length > 0 && password_entry.text.length > 0;
    }
}

