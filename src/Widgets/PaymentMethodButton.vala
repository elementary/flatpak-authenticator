/*
* Copyright (c) 2018 elementary, Inc. (https://elementary.io)
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

public class AppCenter.Widgets.PaymentMethodButton : Gtk.Revealer {
    public signal void selected (ElementaryAccount.Card? card);

    public ElementaryAccount.Card card { get; construct; }
    public bool removable { get; construct set; }

    public Gtk.RadioButton radio { get; private set; }

    public PaymentMethodButton (ElementaryAccount.Card? card, bool _removable = false) {
        Object (
            card: card,
            removable: _removable
        );
    }

    construct {
        reveal_child = true;

        string? title, icon;

        if (card == null) {
            title = _("New Payment Method…");
            icon = null;
        } else {
            title = "%s %s".printf (card.title_case_brand, card.last_four);
            icon = "payment-card-%s".printf (card.brand);
        }

        var title_label = new Gtk.Label (title);
        title_label.halign = Gtk.Align.START;
        title_label.hexpand = true;
        title_label.margin_top = title_label.margin_bottom = 3;

        var radio_grid = new Gtk.Grid ();
        radio_grid.column_spacing = radio_grid.row_spacing = 6;

        radio_grid.attach (title_label, 0, 0);

        Gtk.Image image;

        if (icon != null) {
            image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.LARGE_TOOLBAR);
            radio_grid.attach (image, 1, 0);
        }

        radio = new Gtk.RadioButton (null);
        radio.add (radio_grid);

        radio.toggled.connect (() => {
            if (radio.active) {
                selected (card);
            }
        });

        var radio_style = radio.get_style_context ();
        radio_style.add_class (Gtk.STYLE_CLASS_BUTTON);
        radio_style.add_class (Gtk.STYLE_CLASS_FLAT);

        var overlay = new Gtk.Overlay ();
        overlay.add (radio);

        if (removable) {
            var remove_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic");
            remove_button.halign = Gtk.Align.END;
            remove_button.margin_end = 6;
            remove_button.tooltip_text = _("Remove");
            remove_button.valign = Gtk.Align.CENTER;

            var remove_button_style = remove_button.get_style_context ();
            remove_button_style.add_class (Gtk.STYLE_CLASS_FLAT);
            remove_button_style.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            remove_button.draw.connect (() => {
                image.margin_end = remove_button.get_allocated_width () + radio_grid.column_spacing;
                return false;
            });

            overlay.add_overlay (remove_button);

            remove_button.clicked.connect (() => {
                card.@delete ();
                reveal_child = false;
            });
        }

        add (overlay);
        show_all ();
    }
}


