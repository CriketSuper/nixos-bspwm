#!/usr/bin/env python3
"""Render a normal configuration.nix; never import a previous private module."""
import argparse
import json
from pathlib import Path
import re

DEFAULTS = dict(development=True, virtualisation=True, vpn=True, rdp=True,
                rdpPort=3389, sshPort=5555, timezone="Asia/Yekaterinburg",
                homeStateVersion="25.05")


def read_options(filename):
    raw = json.loads(Path(filename).read_text(encoding="utf-8")) if filename else {}
    if not isinstance(raw, dict):
        raise ValueError("Installer settings must be a JSON object")
    unknown = set(raw) - (set(DEFAULTS) | {"stateVersion"})
    if unknown:
        raise ValueError("Unknown installer settings: " + ", ".join(sorted(unknown)))
    result = {**DEFAULTS, **raw}
    for key in ("development", "virtualisation", "vpn", "rdp"):
        if type(result[key]) is not bool:
            raise ValueError(f"{key} must be true or false")
    for key in ("rdpPort", "sshPort"):
        if type(result[key]) is not int or not 1 <= result[key] <= 65535:
            raise ValueError(f"{key} must be a TCP port from 1 to 65535")
    if not isinstance(result["timezone"], str) or not re.fullmatch(r"[A-Za-z0-9_+\-/]+", result["timezone"]):
        raise ValueError("Invalid timezone")
    for key in ("stateVersion", "homeStateVersion"):
        if key in result and (not isinstance(result[key], str) or not re.fullmatch(r"\d{2}\.\d{2}", result[key])):
            raise ValueError(f"Invalid {key}: expected YY.MM")
    return result


def existing_state(target):
    # Only extract the compatibility version from known public configuration files.
    # Do not evaluate old Nix code or follow imports (especially private.nix).
    for name in ("local/settings.nix", "configuration.nix"):
        path = Path(target) / name
        if path.is_file():
            text = path.read_text(encoding="utf-8")
            text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
            text = re.sub(r"(?m)^\s*#.*$", "", text)
            match = re.search(r'(?<![\w.])(?:system\.|bspwmBuild\.)?stateVersion\s*=\s*"(\d{2}\.\d{2})"\s*;', text)
            if match:
                return match[1]
            if re.search(r'(?<![\w.])(?:system\.|bspwmBuild\.)?stateVersion\s*=', text):
                return None  # Complex values need an explicit answer, not a fallback.
    return None


def nix_string(value):
    return json.dumps(str(value), ensure_ascii=False).replace("${", r"\${")


def render(args, choices):
    if args.profile not in ("universal", "huawei-matebook-d16"):
        raise ValueError("Unknown hardware profile")
    keys = []
    if args.ssh_key:
        content = Path(args.ssh_key).read_text(encoding="utf-8")
        if "PRIVATE KEY" in content:
            raise ValueError("Only a public SSH key is accepted")
        keys = [line.strip() for line in content.splitlines() if line.strip() and not line.lstrip().startswith("#")]
    flag = lambda value: "true" if value else "false"
    state = choices.get("stateVersion", args.state_version)
    text = f'''# Local settings for this PC. Edit this file, then: sudo nixos-rebuild switch
# This file and hardware-configuration.nix are excluded from Git.
{{ pkgs, ... }}: {{
  imports = [
    ./hardware-configuration.nix
    ./modules
    ./profiles/{args.profile}.nix # Change this ONE line to select the other profile.
  ];

  bspwmBuild = {{
    username = {nix_string(args.user)}; uid = {args.uid}; homeDirectory = {nix_string(args.home)};
    homeStateVersion = {nix_string(choices['homeStateVersion'])};
'''
    for key in ("development", "virtualisation", "vpn"):
        text += f"    {key}.enable = {flag(choices[key])};\n"
    text += f'''  }};
  networking.hostName = {nix_string(args.hostname)};
  time.timeZone = {nix_string(choices['timezone'])};
  system.stateVersion = {nix_string(state)}; # Keep the ORIGINAL installation version.

  # SSH: change these native NixOS options here, without editing other modules.
  services.openssh = {{
    enable = {flag(args.ssh_mode != 'off')};
    ports = [ {choices['sshPort']} ];
    openFirewall = true;
    settings = {{
      PermitRootLogin = "no";
      AllowUsers = [ {nix_string(args.user)} ];
      PasswordAuthentication = {flag(args.ssh_mode == 'password')};
      PubkeyAuthentication = {flag(args.ssh_mode != 'password')};
      KbdInteractiveAuthentication = false;
    }};
  }};
'''
    if keys:
        text += f"  users.users.{args.user}.openssh.authorizedKeys.keys = [ "
        text += " ".join(nix_string(key) for key in keys) + " ];\n"
    text += f"  services.bspwmRdp = {{ enable = {flag(choices['rdp'])}; port = {choices['rdpPort']}; }};\n"
    text += '''
  # Extra packages can be added here. The desktop package lists are in packages/.
  environment.systemPackages = with pkgs; [ ];
}
'''
    Path(args.output).write_text(text, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--options")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--detect-state", metavar="TARGET")
    parser.add_argument("--output")
    parser.add_argument("--profile", choices=("universal", "huawei-matebook-d16"), default="universal")
    parser.add_argument("--user")
    parser.add_argument("--uid", type=int)
    parser.add_argument("--home")
    parser.add_argument("--hostname")
    parser.add_argument("--state-version")
    parser.add_argument("--ssh-mode", choices=("off", "password", "key"), default="off")
    parser.add_argument("--ssh-key", default="")
    args = parser.parse_args()
    try:
        if args.detect_state:
            state = existing_state(args.detect_state)
            if not state:
                parser.exit(1, "Cannot detect the original system.stateVersion. Specify it explicitly.\n")
            print(state)
            return
        choices = read_options(args.options)
        if not args.validate_only:
            if any(getattr(args, name) is None for name in ("output", "user", "uid", "home", "hostname", "state_version")):
                parser.error("Rendering requires output, user, uid, home, hostname and state-version")
            render(args, choices)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Settings error: {error}\n")


if __name__ == "__main__":
    main()
