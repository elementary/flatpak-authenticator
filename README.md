# flatpak-authenticator
Authenticate Flatpak installs from an elementary remote

## Building, Testing, and Installation

You need Flathub to download the dependencies.

To build the flatpak, execute:

    flatpak-builder build-dir ./data/io.elementary.flatpak-authenticator.json --force-clean --install-deps-from=flathub
