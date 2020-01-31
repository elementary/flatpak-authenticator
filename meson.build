project(
    'io.elementary.flatpak-authenticator',
    'vala', 'c',
    version: '1.0.0'
)

i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language:'c')

executable(
    meson.project_name(),
    'src/Application.vala',
    'src/AuthenticatorRequest.vala',
    'src/Authenticator.vala',
    'src/Utils.vala',
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('gio-2.0'),
        dependency('dbus-glib-1'),
        dependency('gtk+-3.0')
    ]
)

