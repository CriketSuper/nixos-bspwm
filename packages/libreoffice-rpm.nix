{ pkgs, src ? null }:

let
  archive = if src != null then src else pkgs.fetchurl {
    url = "https://downloadarchive.documentfoundation.org/libreoffice/old/26.8.0.3/rpm/x86_64/LibreOffice_26.8.0.3_Linux_x86-64_rpm.tar.gz";
    sha256 = "24f08911b8c938a3318bd699e71bef034a5b4708499646d2d367e3c922d95137";
  };
  raw = pkgs.stdenvNoCC.mkDerivation {
    pname = "libreoffice-rpm-files";
    version = "26.8.0.3";
    src = archive;
    nativeBuildInputs = [ pkgs.rpmextract ];
    unpackPhase = ''tar -xf "$src"'';
    installPhase = ''
      runHook preInstall
      for rpm in LibreOffice_26.8.0.3_Linux_x86-64_rpm/RPMS/*.rpm; do
        rpmextract "$rpm" >/dev/null 2>&1
      done
      mkdir -p "$out/opt" "$out/share"
      cp -a opt/libreoffice26.8 "$out/opt/"
      cp -a usr/share/icons "$out/share/"
      runHook postInstall
    '';
    dontFixup = true;
  };

  runtime = pkgs.buildFHSEnv {
    name = "libreoffice-26.8";
    targetPkgs = p: with p; [
      zlib stdenv.cc.cc.lib libglvnd
      libX11 libXinerama libXrandr libXrender libXext libXcursor libXfixes libICE libSM
      libxcb libxkbcommon libXScrnSaver
      gtk3 glib gdk-pixbuf cairo pango harfbuzz atk
      cups fontconfig freetype dbus expat
      nss nspr krb5 libpng
      alsa-lib
    ];
    runScript = "${raw}/opt/libreoffice26.8/program/soffice";
  };

  desktop = pkgs.runCommand "libreoffice-26.8-desktop" {} ''
    mkdir -p "$out/share/applications" "$out/share"
    for file in ${raw}/opt/libreoffice26.8/share/xdg/*.desktop; do
      name=$(basename "$file")
      sed -e 's/^Exec=libreoffice26\.8 /Exec=libreoffice-26.8 /' \
          -e 's/^TryExec=libreoffice26\.8$/TryExec=libreoffice-26.8/' \
          "$file" > "$out/share/applications/libreoffice-$name"
    done
    ln -s ${raw}/share/icons "$out/share/icons"
  '';

  aliases = pkgs.runCommand "libreoffice-26.8-aliases" {} ''
    mkdir -p "$out/bin"
    ln -s ${runtime}/bin/libreoffice-26.8 "$out/bin/libreoffice"
    ln -s ${runtime}/bin/libreoffice-26.8 "$out/bin/soffice"
  '';
in
pkgs.symlinkJoin {
  name = "libreoffice-26.8.0.3";
  paths = [ runtime desktop aliases ];
  meta = {
    description = "LibreOffice 26.8 from official RPM archive";
    homepage = "https://www.libreoffice.org/";
    platforms = [ "x86_64-linux" ];
    mainProgram = "libreoffice-26.8";
  };
}
