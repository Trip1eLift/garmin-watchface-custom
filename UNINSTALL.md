# Uninstall / Cleanup Guide

Everything installed during Connect IQ dev environment setup, and how to remove it.

---

## 1. Connect IQ SDK

```bash
rm -rf ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b
```

To remove all SDKs and device profiles (full wipe):

```bash
rm -rf ~/Library/Application\ Support/Garmin/
```

---

## 2. Connect IQ SDK Manager

```bash
rm -rf /Applications/SdkManager.app
```

---

## 3. OpenJDK 26 (installed via Homebrew)

```bash
brew uninstall openjdk
```

To also remove its dependencies if nothing else uses them:

```bash
brew autoremove
```

---

## 4. Monkey C VS Code Extension

```bash
code --uninstall-extension garmin.monkey-c
```

---

## 5. Shell Profile Entries (~/.zshrc)

Remove these 3 lines from `~/.zshrc`:

```bash
# Connect IQ SDK
export JAVA_HOME=/opt/homebrew/opt/openjdk
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin:$PATH"
```

---

## 6. Developer Signing Keys (in project directory)

```bash
rm developer_key.pem developer_key.der
```

> These are local-only self-signed keys used to sign simulator builds. They have no value outside this dev setup.

---

## 7. Temp Download Files

```bash
rm -f /tmp/connectiq-sdk-manager.dmg /tmp/connectiq-sdk-9.1.0.dmg
```

---

## All-in-one

Run everything above in sequence:

```bash
# SDK and devices
rm -rf ~/Library/Application\ Support/Garmin/

# SDK Manager app
rm -rf /Applications/SdkManager.app

# Java
brew uninstall openjdk && brew autoremove

# VS Code extension
code --uninstall-extension garmin.monkey-c

# Signing keys (from project root)
rm -f developer_key.pem developer_key.der

# Temp files
rm -f /tmp/connectiq-sdk-manager.dmg /tmp/connectiq-sdk-9.1.0.dmg
```

Then manually edit `~/.zshrc` to remove the 4-line Connect IQ SDK block.
