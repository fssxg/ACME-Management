## 🌐 [中文](https://github.com/woixd/ACME-Management/blob/main/README-%E4%B8%AD%E6%96%87.md)/[EN](https://github.com/woixd/ACME-Management/blob/main/README.md)

# ACME.sh 多系统自动证书签发脚本

这是一个基于 [acme.sh](https://github.com/acmesh-official/acme.sh) 的自动 SSL/TLS 证书管理脚本，支持 Let's Encrypt 免费证书签发、续签与卸载。

✅ 支持的系统：
- Debian
- Ubuntu
- CentOS

✅ 支持的 Web 服务：
- Nginx
- Apache
- Caddy

---

## 🚀 一键安装脚本

你可以通过以下命令一键安装并运行本脚本：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/woixd/ACME-Management/refs/heads/main/ACME_CN.sh)
```

> ⚠️ 注意：请确保你使用的是 **root 用户** 或具有 `sudo` 权限。

---

## 🔧 脚本功能

1. 签发 Let's Encrypt 免费 SSL 证书（支持 ECC）
2. 自动检测运行中的 Web 服务（Nginx/Apache/Caddy），签发前自动停止，签发后自动恢复
3. 可指定证书保存路径，默认保存在 `/root/SSL`
4. 自动设置 cron，每月自动续签证书
5. 签发成功后输出所有已签发域名列表
6. 支持卸载指定域名的证书及其文件
7. 自动合成并保存完整链证书（`fullchain.pem`）

---

## 🛠️ 使用流程

运行脚本后，你将看到以下提示：

```bash
请选择操作：
1. 签发证书
2. 卸载证书
```

### ▶️ 1. 签发证书

脚本将询问你以下信息：

- 要签发的域名（例如：`example.com`）
- 证书保存路径（默认 `/root/SSL`）

然后它会自动执行以下操作：

- 检查/安装依赖
- 安装 acme.sh（如未安装）
- 暂停运行中的 Web 服务
- 使用 standalone 模式签发证书
- 安装并生成以下文件：
  - `/root/SSL/example.com.key` – 私钥
  - `/root/SSL/example.com.crt` – 证书
  - `/root/SSL/example.com.ca.crt` – CA 根证书
  - `/root/SSL/example.com.fullchain.pem` – 完整链证书（建议使用此文件）

- 重启你的 Web 服务

签发成功后将列出所有当前已签发域名。

### ▶️ 2. 卸载证书

你可以卸载某个已经签发的证书，脚本将自动删除：

- acme.sh 的域名配置
- 你指定路径下的证书文件（例如 `/root/SSL/example.com.*`）

---

## 🧩 示例：Nginx 配置证书

如果你使用的是 Nginx，可以这样配置：

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

> 💡 建议使用 `fullchain.pem`，它包含了完整的证书链，更兼容客户端。

---

## 🔁 自动续签说明

- 脚本会自动添加每月运行一次的 `cron` 任务。
- 只会尝试续签通过本脚本签发的域名证书。
- 续签后将自动覆盖相应的 `.key` 和 `.fullchain.pem` 等文件。

---

## ❌ 卸载说明

运行脚本选择“卸载证书”并输入要卸载的域名，即可：

- 删除对应的 `.key`、`.crt`、`.pem` 文件
- 从 acme.sh 管理中移除该域名

---

## 📂 证书文件结构说明（默认路径 `/root/SSL`）：

| 文件名 | 说明 |
|--------|------|
| `example.com.key` | 证书私钥 |
| `example.com.crt` | 域名证书 |
| `example.com.ca.crt` | 根证书（CA） |
| `example.com.fullchain.pem` | 完整链证书（推荐用于配置） |

---

## 📢 常见问题

### Q: 可以多次签发同一个域名吗？
A: 可以，脚本默认启用 `--force` 强制覆盖旧的 key 和证书。

### Q: 如何检查 nginx 配置是否正确？
A: 执行 `nginx -t` 检查语法，然后使用 `systemctl restart nginx` 重启服务。

### Q: 使用其他端口的服务会影响签发吗？
A: 会。签发时需确保端口 80/443 未被占用，或关闭相关服务由脚本自行签发。

---

## ❤️ 开源许可

MIT License - 免费 / 修改 / 扩展。  
如果你喜欢这个项目，欢迎点 ⭐Star 支持！
