{ fetchurl, src ? null, stdenv, lib, rpmextract, autoPatchelfHook, makeWrapper, glib, nss, nspr, dbus, at-spi2-atk, cups, cairo, gtk3, gdk-pixbuf, pango, libX11, libXcomposite, libXdamage, libXext, libXfixes, libXrandr, libgbm, expat, libxcb, libxkbcommon, systemd, alsa-lib, libglvnd, libusb1 }:

stdenv.mkDerivation {
  pname = "chatgpt-desktop";
  version = "26.1021.22027";
  src = if src != null then src else fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/rpm/x86_64/chatgpt-26.1021.22027-1.x86_64.rpm";
    sha256 = "d5069043701a12760cce0447f7688859e9988dfbb04daaa9be0be0b762ff895f";
  };

  dontUnpack = true;
  nativeBuildInputs = [ rpmextract autoPatchelfHook makeWrapper ];
  buildInputs = [
    glib nss nspr dbus at-spi2-atk cups cairo gtk3 gdk-pixbuf pango
    libX11 libXcomposite libXdamage libXext libXfixes libXrandr
    libgbm expat libxcb libxkbcommon systemd alsa-lib libglvnd
    libusb1
  ];
  # The RPM also carries optional musl builds and shims for other Qt apps.
  # The desktop app itself uses Electron/GTK on this machine.
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libQt5Core.so.5" "libQt5Gui.so.5" "libQt5Widgets.so.5"
    "libQt6Core.so.6" "libQt6Gui.so.6" "libQt6Widgets.so.6"
  ];

  installPhase = ''
    runHook preInstall
    rpmextract "$src" >/dev/null 2>&1
    mkdir -p "$out/lib" "$out/bin" "$out/share"
    cp -a usr/lib/chatgpt "$out/lib/"
    ln -s "$out/lib/chatgpt/codex-launcher" "$out/bin/chatgpt"
    cp -a usr/share/applications "$out/share/"
    # Keep the app and Codex deep links; documents and web links belong to their
    # normal desktop handlers, not the ChatGPT file-import entry point.
    sed -i 's|^MimeType=.*|MimeType=x-scheme-handler/codex;|' \
      "$out/share/applications/chatgpt.desktop"
    cp -a usr/share/pixmaps "$out/share/"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/lib/chatgpt/ChatGPT" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ gtk3 nss libglvnd alsa-lib ]}
  '';

  meta = {
    description = "Official ChatGPT desktop preview with Codex";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.unfree;
    mainProgram = "chatgpt";
  };
}
