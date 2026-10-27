{ obsidian, lib }:
let icon = "${./assets/obsidian-logo-gradient.svg}"; in
# The official SVG is kept locally: an icon download must not block the OS build.
obsidian.overrideAttrs (old: {
  inherit icon;
  installPhase = let
    phase = lib.replaceStrings
      [ (toString old.icon) ] [ icon ]
      old.installPhase;
    # Replacing the path alone retains the original fetch derivation's context.
    # Drop only that dependency; preserve desktopItem and all other references.
    context = builtins.removeAttrs (builtins.getContext phase)
      (builtins.attrNames (builtins.getContext (toString old.icon)));
  in builtins.appendContext (builtins.unsafeDiscardStringContext phase) context;
})
