# 🔐 Gopass Secret Store Recovery Guide

## Critical Information

**Age Passphrase**: `escapable diameter silk discover`
**GitHub Backup**: https://github.com/verlyn13/gopass-secrets (private)
**Public Key**: `age1x00ljfwm8tzjvyzprs9szckgamg342z7jnxuzu4d6j0rzv5pl4ds40dtnz`

## Recovery Process

### 1. Install Required Tools

```bash
# Fedora/RHEL
sudo dnf install gopass age git

# macOS
brew install gopass age git
```

### 2. Clone Your Backup

```bash
git clone git@github.com:verlyn13/gopass-secrets.git ~/.local/share/gopass/stores/root
```

### 3. Restore Configuration

```bash
# Create config directory
mkdir -p ~/.config/gopass

# Create gopass config
cat > ~/.config/gopass/config << 'EOF'
[mounts]
	path = /home/verlyn13/.local/share/gopass/stores/root
[recipients]
	hash = a3c8f6901685cef233502cc993de6ad50d3354b39118833c67ba24087070933a
EOF
```

### 4. Initialize Age Identity

```bash
# Run setup wizard
gopass setup --crypto age

# When prompted for a passphrase, enter:
# escapable diameter silk discover
```

### 5. Verify Recovery

```bash
# List all secrets
gopass list

# Test retrieving a secret
gopass show <secret-name>
```

## Programmatic Access

Helper scripts are available in `~/bin/`:
- `gp-get <path>` - Retrieve a secret
- `gp-set <path> [value]` - Store a secret
- `gp-list [pattern]` - List secrets
- `gp-sync` - Sync with GitHub

### Non-Interactive Access

```bash
export GOPASS_AGE_PASSWORD="escapable diameter silk discover"
gopass show my/secret
```

## Daily Operations

### Add a New Secret
```bash
gopass insert personal/github-token
# Or pipe from stdin
echo "secret123" | gopass insert -f personal/api-key
```

### Retrieve a Secret
```bash
# Show in terminal
gopass show personal/github-token

# Copy to clipboard
gopass show -c personal/github-token

# Get only the password (no metadata)
gopass show -o personal/github-token
```

### Generate a Password
```bash
gopass generate email/gmail 20
```

### Sync with Remote
```bash
gopass sync
# Or use the helper
gp-sync
```

## Backup Strategy

1. **Automatic**: Daily systemd timer backs up to GitHub
2. **Manual**: Run `gp-sync` or `gopass sync`
3. **Offline**: Keep this recovery document in a secure location

## Cross-Platform Notes

### macOS Differences
- Config path: `~/.config/gopass/` (same)
- Store path: `~/.local/share/gopass/stores/root` (same)
- Use `brew` instead of `dnf` for installation

### Environment Variables
```bash
export GOPASS_AGE_PASSWORD="escapable diameter silk discover"
export GOPASS_STORE_DIR="$HOME/.local/share/gopass/stores/root"
```

## Security Best Practices

1. **Never** share the age passphrase
2. Keep the GitHub repository **private**
3. Use unique, generated passwords for each service
4. Enable 2FA on GitHub account
5. Regularly rotate critical passwords
6. Test recovery process periodically

## Troubleshooting

### "No identity matched any of the recipients"
- Ensure age passphrase is correct
- Check `~/.config/gopass/age/identities` exists
- Re-run `gopass setup --crypto age`

### Sync Issues
- Verify GitHub access: `gh auth status`
- Check remote: `cd ~/.local/share/gopass/stores/root && git remote -v`
- Manual push: `cd ~/.local/share/gopass/stores/root && git push`

### Permission Denied
- Fix permissions: `chmod 700 ~/.config/gopass ~/.local/share/gopass`
- Fix identities: `chmod 600 ~/.config/gopass/age/identities`

---
**Created**: 2025-08-15
**Store initialized with age encryption**