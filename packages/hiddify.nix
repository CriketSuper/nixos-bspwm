{ stdenv, lib, fetchurl, autoPatchelfHook, makeWrapper, binutils, zstd,
  gtk3, glib, libayatana-appindicator, libayatana-indicator, ayatana-ido,
  libdbusmenu, libglvnd, openssl, curl, xdg-utils, iproute2, gsettings-desktop-schemas }:

stdenv.mkDerivation {
  pname = "hiddify";
  version = "4.1.1";
  src = fetchurl {
    url = "https://github.com/hiddify/hiddify-app/releases/download/v4.1.1/Hiddify-Debian-x64.deb";
    sha256 = "e622abd15f7d4410c5655f3fdcd0fa9300944666fa40ac22761f06f93020f10e";
  };
  nativeBuildInputs = [ autoPatchelfHook makeWrapper binutils zstd ];
  buildInputs = [ gtk3 glib libayatana-appindicator libayatana-indicator
    ayatana-ido libdbusmenu libglvnd openssl curl stdenv.cc.cc.lib ];
  dontStrip = true;
  unpackPhase = ''
    ar x "$src"
    tar -xf data.tar.zst
  '';
  installPhase = ''
    mkdir -p "$out/share" "$out/bin"
    cp -a usr/share/. "$out/share/"
    install -Dm644 "$out/share/hiddify/data/flutter_assets/assets/images/source/ic_launcher_border.png" "$out/share/icons/hicolor/256x256/apps/hiddify.png"
    makeWrapper "$out/share/hiddify/hiddify" "$out/bin/hiddify" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils iproute2 ]} \
      --prefix LD_LIBRARY_PATH : "$out/share/hiddify/lib:${lib.makeLibraryPath [ libglvnd openssl ]}" \
      --prefix XDG_DATA_DIRS : "${gtk3}/share:${gsettings-desktop-schemas}/share"
    printf '\nStartupWMClass=app.hiddify.com\n' >> "$out/share/applications/hiddify.desktop"
  '';
  preFixup = ''
    patchelf --replace-needed ./lib/hiddify-core.so hiddify-core.so "$out/share/hiddify/HiddifyCli"
    addAutoPatchelfSearchPath "$out/share/hiddify/lib"
  '';
  meta = {
    description = "Hiddify multi-protocol VPN client";
    homepage = "https://github.com/hiddify/hiddify-app";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "hiddify";
  };
}
