# Lightsail CI/CD Demo

这是一个独立、可丢弃的验证项目，用来确认下面这条链路可以工作：

```text
GitHub Actions -> GHCR -> SSH -> Lightsail -> Docker Compose -> HTTP health check
```

它不会连接数据库，也不依赖 ChainBridge。容器只监听服务器本机的
`127.0.0.1:18080`，不会占用现有项目的公开端口。

## 文件作用

| 文件 | 作用 |
| --- | --- |
| `Dockerfile` | 构建最小 Nginx 镜像，并写入 Git Commit SHA |
| `index.html` | Demo 首页 |
| `nginx.conf` | 在容器的 8080 端口提供首页和健康检查 |
| `compose.yaml` | 在 Lightsail 上运行指定 SHA 的镜像 |
| `scripts/test.sh` | 本地或 CI 中验证 `/` 和 `/health` |
| `scripts/deploy.sh` | Lightsail 上拉取指定镜像并执行健康检查 |
| `.github/workflows/cicd.yml` | 手动触发的 CI/CD 工作流 |

## 1. 本地验证

需要 Docker 和 Docker Compose：

```bash
./scripts/test.sh
```

成功时会输出：

```text
Demo HTTP checks passed at http://127.0.0.1:<随机端口>
```

也可以手动启动：

```bash
docker compose up -d --build
curl http://127.0.0.1:18080/health
curl http://127.0.0.1:18080/
docker compose down
```

## 2. 创建独立 GitHub 仓库

建议创建名为 `lightsail-cicd-demo` 的独立私有仓库，把本目录中的内容复制到
该仓库根目录。`.github/workflows/cicd.yml` 必须位于仓库根目录的 `.github`
下面，GitHub 才能识别。

## 3. 首次准备 Lightsail

通过 Lightsail 浏览器 SSH 登录。下面假设部署用户叫 `deploy`：

```bash
sudo adduser --disabled-password --gecos '' deploy
sudo usermod -aG docker deploy
sudo apt-get update
sudo apt-get install -y curl
sudo mkdir -p /opt/cicd-demo/scripts
sudo chown -R deploy:deploy /opt/cicd-demo
```

为 GitHub Actions 单独生成一把 Ed25519 SSH Key，把公钥加入：

```text
/home/deploy/.ssh/authorized_keys
```

私钥只能保存到 GitHub Environment Secret，不能提交到仓库。

## 4. 配置 GitHub Environment

在仓库中创建名为 `production-demo` 的 Environment。建议启用人工审批。

Environment secrets：

| 名称 | 内容 |
| --- | --- |
| `LIGHTSAIL_SSH_PRIVATE_KEY` | 专用部署私钥的完整内容 |
| `LIGHTSAIL_KNOWN_HOSTS` | 已核对指纹的 Lightsail SSH Host Key |

Environment variables：

| 名称 | 示例 |
| --- | --- |
| `LIGHTSAIL_HOST` | Lightsail 静态 IP 或域名 |
| `LIGHTSAIL_USER` | `deploy` |
| `LIGHTSAIL_SSH_PORT` | `22` |

不要用 `ssh-keyscan` 的结果替代人工核对。管理员应在 Lightsail 浏览器 SSH 中
查看服务器 Host Key 指纹，在本地获取公钥后核对一致，再保存到
`LIGHTSAIL_KNOWN_HOSTS`。

## 5. 运行流水线

进入 GitHub：

```text
Actions -> Demo CI/CD -> Run workflow
```

流水线会：

1. 构建并运行临时容器；
2. 验证 `/health` 返回 `ok`；
3. 验证首页包含 Git Commit SHA；
4. 将镜像推送到 GHCR；
5. 等待 `production-demo` 审批；
6. 复制 Compose 和部署脚本到 Lightsail；
7. 让 Lightsail 拉取该 Commit SHA 的镜像；
8. 启动容器并再次检查两个 HTTP 接口。

验证 Lightsail：

```bash
curl http://127.0.0.1:18080/health
curl http://127.0.0.1:18080/
docker compose -f /opt/cicd-demo/compose.yaml ps
```

## 6. 回滚

在 GitHub Packages 或 Actions 中找到上一个成功部署的完整 Commit SHA，然后在
Lightsail 上执行：

```bash
/opt/cicd-demo/scripts/deploy.sh \
  ghcr.io/<owner>/lightsail-cicd-demo \
  <上一个完整的40位Commit-SHA>
```

回滚成功的判断标准是 `/health` 返回 `ok`，首页显示旧 Commit SHA。

## 安全边界

- 工作流默认只能手动触发，不会在每次提交后自动部署。
- 镜像使用不可变 Commit SHA，不依赖 `latest`。
- SSH 使用独立部署 Key，不使用管理员个人私钥。
- 容器只绑定 `127.0.0.1:18080`。
- Demo 不保存任何生产密钥或业务数据。
- 如果公司不允许 GitHub Runner 通过公网 SSH，应停止在这里，改用 Tailscale、
  VPN 或专用部署 Runner，不要为了跑通测试而降低公司的网络安全要求。
