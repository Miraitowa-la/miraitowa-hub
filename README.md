# Miraitowa Hub · 部署 Demo

一页静态个人网站，用于验证 **GitHub → GitHub Actions → SSH → Docker Compose → 云服务器**。
本版没有数据库或内容后台，后续可以替换为正式应用。

## 本地验证

只预览页面时，可直接用浏览器打开 `index.html`；`revision.txt` 是容器构建时生成的，直接打开 HTML 时该链接不可用。

有 Docker 时，在仓库目录执行：

```bash
docker compose up --build --detach --wait --wait-timeout 120
curl -f http://localhost:18087/
curl -f http://localhost:18087/revision.txt
```

浏览器打开 `http://localhost:18087`，本地构建的提交编号默认为 `local`。
验证结束执行 `docker compose down`。
部署脚本还提供不连接服务器的自检：`bash tests/deploy.test.sh`。

## 已包含的流程

- 推送到 `main` 后自动执行，也可以在 Actions 页面手动运行。
- 先在 GitHub Runner 构建容器，检查首页和提交编号。
- 检查通过后，通过 SSH 在服务器拉取这次运行对应的确切提交。
- 用 Docker Compose 构建、启动服务，等待健康检查通过，再核对提交编号。
- 页面监听服务器 **18087** 端口，服务器目录固定为登录用户的 `~/apps/miraitowa-hub`。

## 1. 准备云服务器（你操作）

先在自己电脑的终端登录服务器，替换端口、用户名和 IP：

```powershell
ssh -p 22 你的用户名@你的服务器IP
```

下面的安装和密钥命令都在 **服务器的 Linux 终端** 执行。
先运行 `cat /etc/os-release` 确认系统版本；以下 apt 安装命令仅针对 Ubuntu 24.04。

需要一台能连接 GitHub 和 Docker 镜像仓库的 Linux 服务器，安装 Bash、Git、curl、Docker Engine 和 Docker Compose v2。
SSH 登录用户需要能直接执行 `docker`，部署不使用交互式 sudo。

如果使用 **Ubuntu 24.04**，可以通过系统软件仓库安装：

```bash
sudo apt-get update
sudo apt-get install -y git curl docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

退出 SSH 并重新登录，让用户组生效，然后确认：

```bash
docker info
docker compose version
```

如果系统不同或上述软件包不可用，按 [Docker 官方安装文档](https://docs.docker.com/engine/install/) 安装 Engine 和 Compose 插件。
Docker 用户组具有高权限，只给可信的部署用户使用。

确保 18087 端口没有被其他服务占用：

```bash
sudo ss -ltnp 'sport = :18087'
```

没有显示监听记录就表示当前端口空闲。这里修改的是网页访问端口；SSH 登录端口沿用你服务器的现有配置。

不要把已有项目放在 `~/apps/miraitowa-hub`；这个目录专用于本 Demo。
首次部署会自动克隆公开仓库，服务器无需配置 GitHub token。

## 2. 创建 Actions 专用 SSH 密钥（你操作）

在服务器上，用实际部署用户执行下面命令。若同名密钥已存在，另取文件名，不要覆盖。

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/github_actions_miraitowa -N '' -C 'miraitowa-hub-actions'
cat ~/.ssh/github_actions_miraitowa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

将 `~/.ssh/github_actions_miraitowa` 的完整私钥内容保存到下一步的 `SSH_PRIVATE_KEY` Secret。
在自己的终端运行 `cat ~/.ssh/github_actions_miraitowa` 可显示私钥供复制，包含 BEGIN / END 行。
私钥只在你自己的终端和 GitHub Secrets 中处理，不提交到仓库、不发到聊天。
保管好私钥；完成配置后可移走服务器上的这份私钥，`authorized_keys` 中的公钥需要保留。

## 3. 配置 GitHub Actions Secrets（你操作）

打开 [仓库 Secrets 设置](https://github.com/Miraitowa-la/miraitowa-hub/settings/secrets/actions)，点击 **New repository secret**，逐个添加：

| 名称 | 值 |
| --- | --- |
| `SSH_HOST` | 服务器公网 IPv4 或主机名，不带 `http://` |
| `SSH_USER` | 上一步配置公钥、能执行 Docker 的 Linux 用户名 |
| `SSH_PORT` | SSH 端口，省略时默认 22 |
| `SSH_PRIVATE_KEY` | 专用私钥全文，包括 BEGIN / END 行 |
| `SSH_KNOWN_HOSTS` | 可信服务器的 SSH 主机公钥记录，生成方式见下方 |

通过云厂商控制台或已可信的 SSH 会话，在服务器运行下列命令。
把 `203.0.113.10` 和 `22` 换成与你的 `SSH_HOST`、`SSH_PORT` 一致的值：

```bash
server_host='203.0.113.10'
server_port='22'
host_label="$server_host"
if [ "$server_port" != '22' ]; then
  host_label="[$server_host]:$server_port"
fi
awk -v host="$host_label" '{print host, $1, $2}' /etc/ssh/ssh_host_ed25519_key.pub
```

把输出的一整行保存到 `SSH_KNOWN_HOSTS`。这是主机公钥，不是用户的 `.pub` 文件。
当前 Demo 的 `SSH_HOST` 支持 IPv4 和主机名；使用 IPv6 时需要调整工作流的主机校验。

## 4. 启动部署并访问（你操作）

1. 打开 [Actions 页面](https://github.com/Miraitowa-la/miraitowa-hub/actions)。
2. 选择 **Check and deploy demo** → **Run workflow** → 选择 `main` → 运行。
3. 确认 `check` 和 `deploy` 都显示绿色。
4. 在云服务器安全组开放 TCP 18087 入站；如果启用了 UFW，也执行 `sudo ufw allow 18087/tcp`。保留现有 SSH 规则。
5. 浏览器访问 `http://你的公网IP:18087`。
6. 打开 `http://你的公网IP:18087/revision.txt`，应与这次 Actions 运行的提交 SHA 一致。

Secrets 配置前，首次运行的 `deploy` 会明确报告缺失的 Secret，这是尚未完成配置，不代表容器检查失败。

## 5. 验证自动更新

修改仓库 `index.html` 中的 `DEMO 01` 为 `DEMO 02`，提交到 `main`。
等自动触发的 Actions 两个任务都通过后，刷新网页，应看到新文字；提交编号也应随之更新。
这个步骤才完整验证了“提交更新后服务器自动部署”的闭环。

## 域名和 HTTPS

本 Demo 先用 IP + 18087 验证流程。
后续将 `hub.miraitowa.xyz` 解析到服务器，并配置反向代理和 HTTPS；已有网站的服务器应复用现有反向代理。
没有反向代理时，仅设置 DNS 不会让 `https://hub.miraitowa.xyz` 自动可用。

## 故障定位

- `check` 失败：查看 Actions 的容器日志或镜像拉取错误。
- SSH 失败：核对 IP、端口、用户名、公钥、私钥和主机公钥；确认安全组允许 SSH。
- Docker permission denied：确认部署用户的 Docker 权限，重新登录后再验证。
- 服务器无法拉取 GitHub 或镜像：检查服务器网络，Actions 超时不会修复网络问题。
- 端口被占用：释放 18087，或同步修改 Compose 和两个提交编号检查中的端口。
- 网页无法访问：先在服务器执行 `curl -f http://127.0.0.1:18087/`，再检查安全组和防火墙。

服务器上可查看服务状态和日志：

```bash
cd ~/apps/miraitowa-hub
docker compose ps
docker compose logs --tail=100
```

本 Demo 不包含自动回滚或零停机切换，容器更新可能短暂中断访问。
GitHub 保存代码，不保存将来可能添加的数据库和上传文件。
