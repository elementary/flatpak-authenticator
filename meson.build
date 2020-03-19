project(
    'io.elementary.flatpak-authenticator',
    'vala', 'c',
    version: '1.0.0'
)

i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language:'c')

executable(
    meson.project_name(),
    'src/Dialogs/LoginDialog.vala',
    'src/Dialogs/PurchaseDialog.vala',
    'src/Widgets/PaymentMethodButton.vala',
    'src/Application.vala',
    'src/AuthenticatorRequest.vala',
    'src/Authenticator.vala',
    'src/StoredTokens.vala',
    'src/Utils.vala',
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('gio-2.0'),
        dependency('gee-0.8'),
        dependency('gtk+-3.0'),
        dependency('libsoup-2.4'),
        dependency('json-glib-1.0'),
        dependency('granite'),
        dependency('elementary-account')
    ],
    install: true
)

