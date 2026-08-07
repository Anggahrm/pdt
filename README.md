# pdt

**Zero-to-productive Ubuntu on Android — fully scripted.**

`pdt` bootstraps a complete development environment inside a Termux `proot-distro` Ubuntu container: a themed shell, a modern toolchain, and a curated set of AI coding agents — in two runs, with no manual `apt install` required.

---

## What's in here

| Script | Runs in | Purpose |
|---|---|---|
| [`setup-termux-proot.sh`](./setup-termux-proot.sh) | Termux | Installs `proot-distro`, provisions Ubuntu, creates a sudo-enabled user, installs a Nerd Font, and wires up a one-word `ubuntu` login alias |
| [`ricing-setup.sh`](./ricing-setup.sh) | Ubuntu (inside the container) | Installs zsh, Oh My Zsh, Starship, terminal eye candy, `uv` + Python, Node.js LTS, and an optional set of AI CLI tools |

Both scripts are **idempotent** — re-run either one at any time and it will skip whatever is already in place.

---

## Prerequisites

- [Termux](https://f-droid.org/en/packages/com.termux/) installed from F-Droid (the Play Store build is outdated and unsupported for this workflow)
- An active internet connection
- A few hundred MB of free storage for the Ubuntu container and toolchain

---

## Quick start

### Step 1 — Bootstrap Ubuntu (in Termux)

Download the script, inspect it if you'd like, then run it:

```bash
curl -fLO https://raw.githubusercontent.com/Anggahrm/pdt/refs/heads/main/setup-termux-proot.sh
chmod +x setup-termux-proot.sh
./setup-termux-proot.sh
```

You'll be prompted for a username and password for your new Ubuntu user. Prefer to skip the prompts? Pass them as arguments instead:

```bash
./setup-termux-proot.sh angga your-password
```

When it finishes:

```bash
source ~/.bashrc
ubuntu
```

That's it — `ubuntu` now drops you straight into your Ubuntu container as the user you just created, no flags needed.

### Step 2 — Rice the environment (inside Ubuntu)

From inside the container:

```bash
curl -fLO https://raw.githubusercontent.com/Anggahrm/pdt/refs/heads/main/ricing-setup.sh
chmod +x ricing-setup.sh
./ricing-setup.sh
```

You'll be asked which AI CLI tools to install — pick by number, type `all`, or type `none`:

```
Optional AI CLI tools available for this environment:
  1) OpenCode - open-source AI coding agent for the terminal
  2) Claude Code - Anthropic's official coding agent CLI
  3) 9Router - multi-provider AI request router with quota fallback
  4) Hermes Agent - Nous Research's self-improving agent framework

Select tools to install (e.g. '1,3', 'all', or 'none'):
```

Reload your shell when it's done:

```bash
source ~/.zshrc
```

---

## What gets installed

**`setup-termux-proot.sh`**
- `proot-distro` + Ubuntu container
- A non-root user with passwordless `sudo`
- JetBrainsMono Nerd Font (for prompt icons and glyphs)
- An `ubuntu` alias in `.bashrc` and `.zshrc` for one-word login

**`ricing-setup.sh`**
- zsh, Oh My Zsh, `zsh-autosuggestions`, `zsh-syntax-highlighting`
- [Starship](https://starship.rs) prompt with a Nerd Font preset
- `eza`, `bat`, `neofetch` for a nicer everyday terminal
- [`uv`](https://astral.sh/uv) + Python 3.12
- Node.js LTS via NodeSource
- Optional AI CLI tools (see table below)

---

## AI CLI tools

Installed only if you select them during Step 2:

| Tool | What it is | Install source |
|---|---|---|
| [OpenCode](https://opencode.ai) | Open-source AI coding agent for the terminal | `npm install -g opencode-ai` |
| [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) | Anthropic's official coding agent CLI | `npm install -g @anthropic-ai/claude-code` |
| [9Router](https://9router.com) | Multi-provider AI request router with quota-based fallback | `npm install -g 9router` |
| [Hermes Agent](https://hermes-agent.nousresearch.com) | Nous Research's self-improving, multi-channel agent framework | official install script (bundles its own Node.js) |

You can also skip the prompt entirely:

```bash
./ricing-setup.sh --tools=all                  # install everything
./ricing-setup.sh --tools=none                 # skip AI tools
./ricing-setup.sh --tools=opencode,hermes      # install a specific subset
```

---

## Non-interactive / unattended usage

Both scripts accept arguments so they can run without any prompts — useful for re-provisioning a device or scripting a fresh install end to end:

```bash
./setup-termux-proot.sh angga your-password
./ricing-setup.sh --tools=claude-code
```

---

## Troubleshooting

**`nano: command not found` right after creating a user**
Your new user doesn't have `sudo` yet. Log in as root once (`proot-distro login ubuntu`, no `--user` flag) and re-run `setup-termux-proot.sh` — it installs and configures `sudo` automatically.

**Prompt icons show up as boxes or question marks**
The Nerd Font hasn't loaded yet. Fully restart the Termux app (not just the session) after running `setup-termux-proot.sh`.

**Want to browse container files with a file manager?**
The container lives inside Termux's private storage and isn't visible to file managers without root. With root, enable Root Explorer in your file manager and navigate to:
```
/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/home/<user>/
```
Without root, use an SFTP connection to `127.0.0.1:8022` via `sshd` running in Termux.

**Re-running a script**
Safe to do at any time — both scripts detect what's already installed and skip it.

---

## License

MIT — use, modify, and share freely.
