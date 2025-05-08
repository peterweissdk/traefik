# 💾 Traefik Container Setup

Automated setup for Traefik reverse proxy in an LXC container with proper security configurations and dynamic routing capabilities.

## ✨ Features

- Automated LXC container creation and configuration
- Secure Traefik installation with proper permissions
- Dynamic configuration support
- TLS/SSL support with automatic certificate management
- Middleware configurations for security and routing
- Systemd service integration
- Automatic updates capability

## 🚀 Quick Start

1. Clone this repository
2. Run the container setup script:
   ```bash
   sudo ./install_traefik_container.sh
   ```
3. The script will:
   - Create an LXC container
   - Install Traefik
   - Configure permissions and security
   - Set up the service

## 🔧 Configuration

Configuration files are stored in `traefik_conf/`:
- `traefik.yaml`: Main Traefik configuration
- `tls.yaml`: TLS/SSL settings
- `middlewares.yaml`: HTTP middleware configurations
- `defaultRouters.yaml`: Default routing rules
- `testRoute.yaml`: Test routing configuration
- `.env`: Environment variables (for DNS challenge credentials)

## 📝 Directory Structure

```
.
├── install_traefik_container.sh
├── install_traefik.sh
├── setup_traefik.sh
├── update_traefik.sh
├── traefik.service
└── traefik_conf/
    ├── traefik.yaml
    ├── .env
    ├── defaultRouters.yaml
    ├── testRoute.yaml
    ├── tls.yaml
    └── middlewares.yaml
```

## 🔍 Health Check

Monitor Traefik's health:
1. Service status:
   ```bash
   systemctl status traefik
   ```
2. View logs:
   ```bash
   journalctl -u traefik
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
