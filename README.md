# linux-misc

Small Linux administration helper scripts.

## SSH key setup

`sshkeysetup` helps you create or reuse an SSH key on your local computer and install the public key on a remote Linux machine.

Use it when you want passwordless SSH login from:

- Linux or macOS: `sshkeysetup`
- Windows PowerShell: `sshkeysetup.ps1`

The original legacy `sshsetup` script is preserved on the `old` branch. The `main` branch uses the modern `sshkeysetup` name.

## What It Does

- Creates a local Ed25519 key if one does not already exist.
- Reuses the existing key if it is already present.
- Creates or repairs the `.pub` public-key file if needed.
- Installs the public key into the remote Linux user's `~/.ssh/authorized_keys`.
- Optionally installs the same key for remote `root` through `sudo`.
- Optionally adds the key to your local SSH agent.
- Verifies key login after setup.

It does not copy your private key to the server. Only the public key is installed remotely.

## Requirements

Remote server:

- Linux or another Unix-like server with SSH enabled.
- A user account you can log in to by password or existing key.
- `sudo` access only if using the root setup option.

Linux/macOS client:

- `ssh`
- `ssh-keygen`
- `ssh-copy-id`

Windows client:

- Windows 10/11 or Windows Server with OpenSSH Client installed.
- PowerShell.
- `ssh` and `ssh-keygen` available in `PATH`.

## Linux Or macOS Usage

From the `linux-misc` directory:

```bash
./sshkeysetup user@example.com --accept-new-host-key
```

With a custom SSH port:

```bash
./sshkeysetup user@example.com --port 2222 --accept-new-host-key
```

With a custom key path:

```bash
./sshkeysetup user@example.com --key ~/.ssh/example_ed25519 --accept-new-host-key
```

Also install the key for remote root through sudo:

```bash
./sshkeysetup user@example.com --root --accept-new-host-key
```

Show all options:

```bash
./sshkeysetup --help
```

## Windows PowerShell Usage

From the `linux-misc` directory in PowerShell:

```powershell
.\sshkeysetup.ps1 user@example.com -AcceptNewHostKey
```

With a custom SSH port:

```powershell
.\sshkeysetup.ps1 user@example.com -Port 2222 -AcceptNewHostKey
```

With a custom key path:

```powershell
.\sshkeysetup.ps1 user@example.com -KeyPath "$env:USERPROFILE\.ssh\example_ed25519" -AcceptNewHostKey
```

Generate a key without a passphrase:

```powershell
.\sshkeysetup.ps1 user@example.com -NoPassphrase -AcceptNewHostKey
```

Also install the key for remote root through sudo:

```powershell
.\sshkeysetup.ps1 user@example.com -Root -AcceptNewHostKey
```

## Default Key Locations

Linux/macOS:

```text
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

Windows:

```text
%USERPROFILE%\.ssh\id_ed25519
%USERPROFILE%\.ssh\id_ed25519.pub
```

## Notes

- `--accept-new-host-key` / `-AcceptNewHostKey` accepts the server host key the first time you connect. Use it only when you trust the server address.
- Keep password login enabled until you verify key login from a separate terminal.
- Prefer Ed25519 keys for normal modern systems.
- RSA is available only for compatibility with older environments.
- DSA is intentionally unsupported.
