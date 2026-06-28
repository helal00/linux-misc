# sshkeysetup Assessment

## Purpose

`sshkeysetup` is the first step in a hardened server workflow: create or reuse a client SSH key, install the public key on a remote Linux account, and verify key login.

It should stay focused on key setup. SSH daemon hardening should be a separate step that runs only after key login has been verified.

## Current State

- `sshkeysetup` supports Linux/macOS clients.
- `sshkeysetup.ps1` supports Windows PowerShell clients.
- Defaults to Ed25519 keys.
- Supports custom ports and custom key paths.
- Supports optional root key installation through `--root` / `-Root`.
- Does not copy the private key to the server.

## Should Password Login Disabling Be Included?

Not directly in `sshkeysetup`.

Disabling password authentication is a server policy change. If it is done before confirming key login in a separate session, it can lock out the operator.

Recommended split:

- `sshkeysetup`: install and verify key login.
- `sshharden`: apply SSH daemon hardening after key login is confirmed.

## Recommended `sshharden` Behavior

A future hardening tool should:

- Detect SSH daemon config paths and include directories.
- Create timestamped backups before edits.
- Add settings in a drop-in file where supported, for example `/etc/ssh/sshd_config.d/99-hardening.conf`.
- Set `PasswordAuthentication no`.
- Set `KbdInteractiveAuthentication no`.
- Set `PermitRootLogin prohibit-password` by default, or `PermitRootLogin no` for stricter setups.
- Keep `PubkeyAuthentication yes`.
- Validate with `sshd -t` before reload.
- Reload SSH without closing the current session.
- Ask the user to verify a new SSH login before removing rollback instructions.
- Provide a rollback command.

## Chain Position

Recommended new-server order:

1. `sshkeysetup`: install keys and verify login.
2. `sshharden`: disable password-based SSH and restrict root login.
3. `server-firewall-base`: set UFW defaults and essential allow rules.
4. `auto-allow-ip`: optionally enable dynamic allow rules for trusted SSH users.
5. `f2b-ufw-enhanced`: install Fail2Ban jails and management layer.
6. `linux-upgradespy` or replacement: report pending security updates and reboot/service-restart needs.

## References

- OpenSSH `sshd_config`: https://man7.org/linux/man-pages/man5/sshd_config.5.html
- UFW rule model: https://manpages.ubuntu.com/manpages/noble/man8/ufw.8.html
