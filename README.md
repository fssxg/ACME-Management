[中文](https://github.com/fssxg/ACME-Management/blob/main/README-%E4%B8%AD%E6%96%87.md)/[EN](https://github.com/fssxg/ACME-Management/blob/main/README.md)

# 📜 ACME.sh Multi-System Automatic Certificate Issuance Script

This is an automated SSL/TLS certificate management script based on [acme.sh](https://github.com/acmesh-official/acme.sh), supporting the issuance, renewal, and removal of free Let's Encrypt certificates.

✅ Supported systems:
- Debian
- Ubuntu
- CentOS

✅ Supported web servers:
- Nginx
- Apache
- Caddy

---

## 🚀 One-Click Installation Script

You can install and run the script with the following command:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/fssxg/ACME-Management/refs/heads/main/ACME.sh)
```

> ⚠️ Note: Make sure you are using the **root user** or have `sudo` privileges.

---

## 🔧 Script Features

1. Issue free Let's Encrypt SSL certificates (ECC supported)
2. Automatically detect running web services (Nginx/Apache/Caddy), stop them before issuance, and restart after
3. Customizable certificate save path (default: `/root/SSL`)
4. Automatically set a cron job for monthly certificate renewal
5. Display all issued domains after successful issuance
6. Support uninstalling specific domain certificates and files
7. Automatically generate and save the full chain certificate (`fullchain.pem`)

---

## 🛠️ Usage Process

After running the script, you'll see the following prompt:

```bash
Please choose an option:
1. Issue Certificate
2. Uninstall Certificate
```

### ▶️ 1. Issue Certificate

The script will ask for the following:

- Domain name to issue (e.g., `example.com`)
- Certificate save path (default: `/root/SSL`)

Then, it will automatically:

- Check/install dependencies
- Install acme.sh (if not installed)
- Stop any running web service
- Issue certificate using standalone mode
- Install and generate these files:
  - `/root/SSL/example.com.key` – Private key
  - `/root/SSL/example.com.crt` – Certificate
  - `/root/SSL/example.com.ca.crt` – CA root certificate
  - `/root/SSL/example.com.fullchain.pem` – Full chain certificate (recommended)

- Restart your web service

All currently issued domains will be listed upon success.

### ▶️ 2. Uninstall Certificate

You can uninstall an issued certificate, and the script will automatically delete:

- The acme.sh domain configuration
- Certificate files in the specified path (e.g., `/root/SSL/example.com.*`)

---

## 🧩 Example: Nginx Certificate Configuration

If you’re using Nginx, configure it like this:

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate     /root/SSL/example.com.fullchain.pem;
    ssl_certificate_key /root/SSL/example.com.key;

    location / {
        proxy_pass http://localhost:8080;
    }
}
```

> 💡 It’s recommended to use `fullchain.pem` for better client compatibility.

---

## 🔁 Auto Renewal Notes

- The script adds a monthly `cron` task automatically.
- Only domains issued through this script will be renewed.
- Renewals will overwrite the respective `.key` and `.fullchain.pem` files.

---

## ❌ Uninstallation Instructions

Run the script, choose "Uninstall Certificate", and enter the domain to uninstall. This will:

- Delete related `.key`, `.crt`, `.pem` files
- Remove the domain from acme.sh management

---

## 📂 Certificate File Structure (default path: `/root/SSL`):

| Filename | Description |
|----------|-------------|
| `example.com.key` | Private key |
| `example.com.crt` | Domain certificate |
| `example.com.ca.crt` | CA root certificate |
| `example.com.fullchain.pem` | Full chain certificate (recommended) |

---

## 📢 Frequently Asked Questions

### Q: Can I issue the same domain multiple times?
A: Yes, the script uses `--force` to overwrite old keys and certificates by default.

### Q: How to check if Nginx configuration is correct?
A: Run `nginx -t` to test the syntax, then `systemctl restart nginx` to restart the service.

### Q: Will other services using different ports interfere with issuance?
A: Yes. Ensure ports 80/443 are free during issuance, or stop relevant services to allow the script to proceed.

---

For feedback or issues, please visit the project repository.
