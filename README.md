# 💾 Traefik Container Setup In Proxmox
[![Static Badge](https://img.shields.io/badge/Container-LXC-white?style=flat&logo=linuxcontainers&logoColor=white&logoSize=auto&labelColor=black)](https://linuxcontainers.org/lxc/introduction/)
[![Static Badge](https://img.shields.io/badge/Ubuntu-24.04-white?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=black)](https://ubuntu.com/)
[![Static Badge](https://img.shields.io/badge/Traefik-Proxy-white?style=flat&logo=traefikproxy&logoColor=white&logoSize=auto&labelColor=black)](https://traefik.io/)
[![Static Badge](https://img.shields.io/badge/Bash-script-white?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![Static Badge](https://img.shields.io/badge/GPL-V3-white?style=flat&logo=gnu&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/licenses/gpl-3.0.en.html/)

Automated setup for Traefik reverse proxy in an LXC container with proper security configurations and dynamic routing capabilities.

## ✨ Features

- Automated LXC container creation and configuration
- Secure Traefik installation with proper permissions
- Dynamic configuration support
- TLS/SSL support with automatic certificate management
- Middleware configurations for security and routing
- Systemd service integration
- Automatic updates capability
- MOTD notifications for available updates

## 🚀 Quick Start

Run the following command to install Traefik in Proxmox:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/peterweissdk/traefik/refs/heads/main/install.sh)"
```

This will:
- Create an LXC container
- Install Traefik
- Configure permissions and security
- Set up the service

## 🔧 Configuration

Configuration files are stored in `/etc/traefik` & `/etc/traefik/dynamic`  
Please change the configuration files to match your needs  

- `traefik.yaml`: Main Traefik configuration
- `tls.yaml`: TLS/SSL settings
- `middlewares.yaml`: HTTP middleware configurations
- `defaultRouters.yaml`: Default routing rules
- `testRoute.yaml`: Test routing configuration
- `.env`: Environment variables (for DNS challenge credentials)

### Authentication

To generate MD5 hashed passwords for middleware authentication:

```bash
openssl passwd -1 "my-password"
```

Default credentials:
- Username: `root`
- Password: `traefik`

## 📝 Directory Structure

```
.
├── traefik_conf/
│   ├── .env
│   ├── traefik.yaml
│   ├── defaultRouters.yaml
│   ├── middlewares.yaml
│   ├── testRoute.yaml
│   └── tls.yaml
├── install.sh
├── install_traefik.sh
├── install_traefik_container.sh
├── setup_traefik.sh
├── traefik_update.sh
├── traefik.service
├── 99-traefik-updates
├── LICENSE
└── README.md
```

## 🔍 Health Check

Monitor Traefik's health:
1. Service status:
   ```bash
   systemctl status traefik
   ```
2. View logs:
   ```bash
   journalctl -u --boot traefik
   ```
3. Access dashboard (if enabled):
   ```
   https://your-domain/dashboard/
   ```
## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🆘 Support

If you encounter any issues or need support, please file an issue on the GitHub repository.

## 📄 License

This project is licensed under the GNU GENERAL PUBLIC LICENSE v3.0 - see the [LICENSE](LICENSE) file for details.
