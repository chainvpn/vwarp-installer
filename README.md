# Vwarp Auto-Installer 🚀

An automated installation toolkit for deploying **Vwarp** on Linux servers. Includes a simple single-instance installer and a full-featured multi-instance Pro manager — both detect your architecture, pull the latest release, and wire everything up as resilient `systemd` services.

### 🌟 Acknowledgements & Credits

This installer is built to easily deploy the core **Vwarp** engine. Full credit and massive respect go to the original author and maintainer: **[@voidr3aper-anon](https://github.com/voidr3aper-anon)**.

Please visit the [official Vwarp repository](https://github.com/voidr3aper-anon/Vwarp) to star the project, read the detailed protocol documentation, and support the core development.

---

## ✨ Features

- **Auto-Architecture Detection** — Automatically fetches the correct binary (`amd64` or `arm64`) for your server.
- **Always Up-to-Date** — Pulls the newest release tag directly from the official Vwarp GitHub API.
- **Zero-Downtime Design** — Sets up persistent `systemd` background services that automatically restart on crashes or reboots.
- **Auto-Scanning Included** — Configures Vwarp with the `--scan` flag by default to automatically find and connect to working endpoints.
- **Multi-Instance Support** *(Pro)* — Deploy a full fleet of proxy instances across local or geo-targeted country modes in one run.

---

## 📦 Scripts

| Script | Purpose |
|---|---|
| `install.sh` | Single-instance quick install |
| `install-pro.sh` | Multi-instance fleet manager with country routing |

---

## 🚀 Quick Install — Single Instance

Install or update a single Vwarp instance as a `systemd` service:

```bash
curl -sL https://raw.githubusercontent.com/chainvpn/vwarp-installer/main/install.sh | sudo bash
```

This sets up one Vwarp instance on port `1086` binding to `127.0.0.1`, running with `--scan` for automatic endpoint discovery.

---

## ⚡ Pro Install — Multi-Instance Fleet Manager

For deploying multiple instances (e.g. for proxy rotation, geo-routing, or load distribution):

```bash
curl -sL https://raw.githubusercontent.com/chainvpn/vwarp-installer/main/install-pro.sh | sudo bash
```

### Pro Deployment Modes

| Mode | Description |
|---|---|
| **Local** | Deploys N instances on sequential ports, all using `--scan` |
| **Different Countries** | Deploys N instances, rotating through a list of 30+ country codes via `--cfon --country` |
| **All Countries** | Deploys one instance per country in the full list (30 instances) |

### Supported Countries

`US` `CA` `BR` `GB` `DE` `FR` `IT` `ES` `NL` `SE` `NO` `DK` `FI` `CH` `AT` `BE` `IE` `PT` `PL` `CZ` `HU` `RO` `BG` `HR` `EE` `LV` `SK` `RS` `JP` `SG` `AU` `IN`

### Pro Manager Menu

If existing Vwarp instances are detected, the script presents a management menu:

```
1) Fresh Install / Reconfigure Everything
2) Test current instances (Check Outbound IPs)
3) Exit
```

The **Test** option probes each running instance via its SOCKS5 port and displays a live table of outbound IPs — useful for verifying geo-routing is working correctly.

### Port Allocation

Instances are assigned sequential ports starting from `1086`:

```
Instance 1 → port 1086
Instance 2 → port 1087
Instance 3 → port 1088
...
```

### Bind IP

During setup you'll be prompted for a bind IP:

- `127.0.0.1` *(default)* — local access only, safe for single-server use
- `0.0.0.0` — expose publicly (ensure your firewall is configured)

---

## 🔧 Requirements

- Linux (Ubuntu/Debian recommended)
- `systemd`
- `curl`
- `unzip` (auto-installed if missing)
- Root or `sudo` access

---

## 🛠 Managing Services

Each instance runs as a named `systemd` service (`vwarp1`, `vwarp2`, etc.):

```bash
# Check status of all instances
systemctl status 'vwarp*.service'

# Stop a specific instance
sudo systemctl stop vwarp3.service

# View logs for instance 2
journalctl -u vwarp2.service -f
```

---

## 🔒 Security Notes

- Binding to `127.0.0.1` is strongly recommended unless you have firewall rules in place.
- Services run as `root` — consider restricting this for production environments.
- SOCKS5 proxies on exposed ports have no authentication by default.

---

## License

This installer is provided as-is. The Vwarp binary itself is the property of [@voidr3aper-anon](https://github.com/voidr3aper-anon). Please respect the upstream project's license.
