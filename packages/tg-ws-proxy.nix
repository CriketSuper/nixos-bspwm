{ fetchurl, src ? null, stdenv, lib, rpmextract, autoPatchelfHook, makeWrapper, zlib, gtk3, glib, gdk-pixbuf, pango, cairo, atk, at-spi2-atk, wayland, libayatana-appindicator, libX11, libxcb, libXext, libXrender, libXft, fontconfig, freetype }:

stdenv.mkDerivation {
  pname = "tg-ws-proxy";
  version = "1.10.4";
  src = if src != null then src else fetchurl {
    url = "https://github.com/Flowseal/tg-ws-proxy/releases/download/v1.10.4/TgWsProxy_linux_amd64.rpm";
    sha256 = "5278f09ec87e8784084316b803f8d586278aee2614a77f7ba0dc9a7208279764";
  };

  dontUnpack = true;
  nativeBuildInputs = [ rpmextract autoPatchelfHook makeWrapper ];
  buildInputs = [ zlib gtk3 glib gdk-pixbuf pango cairo atk at-spi2-atk wayland libayatana-appindicator libX11 libxcb libXext libXrender libXft fontconfig freetype ];

  installPhase = ''
    runHook preInstall
    rpmextract "$src" >/dev/null
    install -Dm755 usr/bin/tg-ws-proxy "$out/bin/tg-ws-proxy"
    install -Dm644 usr/share/applications/tg-ws-proxy.desktop "$out/share/applications/tg-ws-proxy.desktop"
    install -Dm644 usr/share/icons/hicolor/256x256/apps/tg-ws-proxy.png "$out/share/icons/hicolor/256x256/apps/tg-ws-proxy.png"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/tg-ws-proxy" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ gtk3 glib gdk-pixbuf pango cairo atk at-spi2-atk wayland libayatana-appindicator libX11 libxcb libXext libXrender libXft fontconfig freetype ]}
  '';

  meta = {
    description = "Flowseal Telegram WebSocket proxy";
    homepage = "https://github.com/Flowseal/tg-ws-proxy";
    platforms = [ "x86_64-linux" ];
    mainProgram = "tg-ws-proxy";
  };
}
