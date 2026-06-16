# Vwarp Auto-Installer 🚀

An automated, one-line installation script for deploying **Vwarp** on Linux servers. This script detects your system architecture, downloads the latest compiled release, and configures it as a highly available systemd service.

### 🌟 Acknowledgements & Credits
This installer is built to easily deploy the core **Vwarp** engine. Full credit and massive respect go to the original author and maintainer: **[@voidr3aper-anon](https://github.com/voidr3aper-anon)**. 

Please visit the [official Vwarp repository](https://github.com/voidr3aper-anon/Vwarp) to star the project, read the detailed protocol documentation, and support the core development.

---

## ✨ Features
* **Auto-Architecture Detection:** Automatically fetches the correct binary (`amd64` or `arm64`) for your server.
* **Always Up-to-Date:** Pulls the newest release tag directly from the official Vwarp GitHub API.
* **Zero-Downtime Design:** Sets up a persistent `systemd` background service that automatically restarts on crashes or server reboots.
* **Auto-Scanning Included:** Configures Vwarp to run with the `--scan` flag by default to automatically find and connect to working endpoints.

---

## 🚀 Quick Install (One-Liner)

To install or update Vwarp, run the following command as root or a user with `sudo` privileges:

```bash
curl -sL [https://raw.githubusercontent.com/chainvpn/vwarp-installer/main/install.sh](https://raw.githubusercontent.com/chainvpn/vwarp-installer/main/install.sh) | sudo bash
