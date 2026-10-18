#!/usr/bin/env python3
"""Validate wizard choices and render a local NixOS module without secrets."""
import argparse
import json
from pathlib import Path
import re

DEFAULTS = {
    "development": True,
    "virtualisation": True,
    "vpn": True,
    "rdp": True,
    "rdpPort": 3389,
    "sshPort": 5555,
    "timezone": "Asia/Yekaterinburg",
}


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
    if "stateVersion" in result and (not isinstance(result["stateVersion"], str) or not re.fullmatch(r"\d{2}\.\d{2}", result["stateVersion"])):
        raise ValueError("Invalid stateVersion: expected YY.MM")
    return result


def nix_string(value):
    # SSH public-key comments can contain arbitrary text, including ${...}.
    return json.dumps(str(value), ensure_ascii=False).replace("${", r"\${")


def render(args, choices):
    keys = []
    if args.ssh_key:
        content = Path(args.ssh_key).read_text(encoding="utf-8")
        if "PRIVATE KEY" in content:
            raise ValueError("Only a public SSH key is accepted")
        keys = [line.strip() for line in content.splitlines() if line.strip() and not line.lstrip().startswith("#")]
    flag = lambda value: "true" if value else "false"
    state = choices.get("stateVersion", args.state_version)
    text = "{ ... }: {\n  bspwmBuild = {\n"
    text += f"    username = {nix_string(args.user)}; uid = {args.uid}; homeDirectory = {nix_string(args.home)};\n"
    text += f"    hostName = {nix_string(args.hostname)}; stateVersion = {nix_string(state)};\n"
    text += f"    timeZone = {nix_string(choices['timezone'])};\n"
    for key in ("development", "virtualisation", "vpn"):
        text += f"    {key}.enable = {flag(choices[key])};\n"
    text += f"    ssh = {{ enable = {args.ssh}; port = {choices['sshPort']}; authorizedKeys = [ "
    text += " ".join(nix_string(key) for key in keys) + " ]; };\n  };\n"
    text += f"  services.bspwmRdp = {{ enable = {flag(choices['rdp'])}; port = {choices['rdpPort']}; }};\n}}\n"
    Path(args.output).write_text(text, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--options")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--output")
    parser.add_argument("--user")
    parser.add_argument("--uid", type=int)
    parser.add_argument("--home")
    parser.add_argument("--hostname")
    parser.add_argument("--state-version")
    parser.add_argument("--ssh", choices=("true", "false"), default="false")
    parser.add_argument("--ssh-key", default="")
    args = parser.parse_args()
    try:
        choices = read_options(args.options)
        if not args.validate_only:
            if any(getattr(args, name) is None for name in ("output", "user", "uid", "home", "hostname", "state_version")):
                parser.error("Rendering requires output, user, uid, home, hostname and state-version")
            render(args, choices)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Settings error: {error}\n")


if __name__ == "__main__":
    main()
