Here is the complete, polished Markdown text ready to be pasted directly into your `README.md` file on GitHub.

It uses standard GitHub formatting, clear section breaks, and highlights the code blocks so it looks professional when rendered.

---

```markdown
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

```

*Note: The script will automatically install necessary dependencies like `curl` and `unzip` if they are missing.*

---

## 🛠️ Usage & Management

Once the installation completes, the `vwarp` service will start automatically in the background. You can manage it using standard systemd commands.

**Check if Vwarp is running:**

```bash
sudo systemctl status vwarp

```

**View live logs (Useful for watching the `--scan` process):**

```bash
sudo journalctl -u vwarp -f

```

**Stop / Start / Restart the service:**

```bash
sudo systemctl stop vwarp
sudo systemctl start vwarp
sudo systemctl restart vwarp

```

---

## ⚙️ Customizing Flags & Configuration

By default, the installer sets up Vwarp listening on `127.0.0.1:8086` using the `--scan` flag. If you want to add custom parameters (such as `--gool`, `--masque`, or binding to `0.0.0.0:8086`), you can easily edit the service file.

1. Open the service configuration:
```bash
sudo nano /etc/systemd/system/vwarp.service

```


2. Locate the `ExecStart` line and append your desired flags. For example:
```ini
ExecStart=/opt/vwarp --scan --bind 0.0.0.0:8086 --gool

```


3. Save the file, reload the daemon, and restart the service:
```bash
sudo systemctl daemon-reload
sudo systemctl restart vwarp

```



---

*Built with ❤️ for the Vwarp community.*

```

```
