# 推送到 GitHub 并构建 GHCR 镜像

目标仓库：`https://github.com/a454735639-lab/sunpanel`（**无连字符**）。已确认它是公开空仓库：`size=0`、无 commit、无 refs、默认分支 `main`。

> 旧资料里 `F:/开发区/source` 的 remote 指向 `a454735639-lab/sun-panel`（**带连字符**），该仓库已 404。两者不是同一个仓库。

## 1. 先解决推送权限（当前阻塞点）

本机 `gh` 已登录 `asice999`，但只读检查显示：

```
gh api repos/a454735639-lab/sunpanel --jq '.permissions'
→ {"admin":false,"maintain":false,"pull":true,"push":false,"triage":false}
gh api user/orgs → 空
```

也就是**当前身份对这个公开仓库只有读权限**，不是 owner，也不是组织成员。直接 `git push` 会失败。三选一：

- **切换账号**（推荐）：`gh auth login` 用 `a454735639-lab` 登录；若已添加过第二个账号，用 `gh auth switch -u a454735639-lab`。
- **加协作者**：由 owner 在仓库 Settings → Collaborators 把 `asice999` 加为 **Write** 及以上。
- **转移仓库**：把仓库 transfer 给 `asice999`。

改完后跑只读前置检查（脚本在仓库外，不会被推送）：

```bash
python ../push-preflight.py
# 期望 RESULT: READY，且 repo permissions 显示 push=true
```

它会检查当前账号、仓库 `push`/`admin` 权限、token scopes、本地文件数、workflow 是否仍带自动触发。**不打印令牌、不写入仓库、不执行推送。**

**fine-grained PAT 的额外坑**：推送含 `.github/workflows/*.yml` 的 commit 时，GitHub 可能报 `refusing to allow a PAT to create or update workflow`。需要给该 PAT 加 `Contents: Read & Write` + `Workflows: Read & Write`，或改用勾了 `repo` + `workflow` 的 classic PAT。

> CI 里用的是 Actions 内置 `${{ secrets.GITHUB_TOKEN }}`（workflow 已申请 `packages: write`），**不需要也不应该**把个人 PAT 配成仓库 secret。个人 PAT 只用于本机 `git push`。

## 2. 确认 GHCR 包名

workflow 现在是**仅手动触发**，所以推送源码不会构建、也不会创建包；包名在**第一次成功运行 workflow** 时才定型。默认：

```
ghcr.io/a454735639-lab/sun-panel:latest
```

名字由手动触发时的 `image_name` 输入决定（默认 `sun-panel`），owner 与包名都会自动小写化。要改名，在第一次运行前改 `build-ghcr.yml` 里的 `default`，或运行时直接填 `image_name`。

定型后不可回头的特性：

- 包的可见性在**首次创建时**继承创建它的仓库：公开仓库首推 = `PUBLIC`，私有仓库首推 = `PRIVATE`。
- 包已存在后**不会**随仓库改名/改可见性翻转；REST / GraphQL 没有"改包可见性"端点，只能网页 UI 改。
- **包名一旦用过即被占用**：删除后 30 天 restore 期内别的仓库无法接管同名包；全新包名首推立刻成功。
- 推送权绑定**创建它的仓库 repo id**：仓库改名 id 不变、推送权不变；删除再重建会换 id，旧包推不进去。
- 公开仓库的内置 `GITHUB_TOKEN` 可以创建新包；私有仓库的 `GITHUB_TOKEN` 不能（`installation not allowed to Create organization package`）。本仓库公开，没问题。

## 3. 推送源码

先做完第 1 节的权限检查，再执行：

```bash
cd 04-buildable-repo

git init -b main
git remote add origin https://github.com/a454735639-lab/sunpanel.git
git add .
git commit -m "Import buildable sun-panel community source"
git push -u origin main
```

- 如果远端有初始化 commit（README / LICENSE），先 `git pull --rebase origin main` 再推。
- 文件数应为 358（上游 355 + workflow + 两份文档），约 9 MB。
- **只推这个目录**。不要把 `../01-slim-image/*.tar`、`../03-frontend-injection/*.tar`，或上一轮 `sun-panel-source-restored/image-frontend/`（闭源镜像编译产物）一起推上去。
- 不要把任何令牌写进 remote URL、`.git/config`、源码或文档；用系统凭据管理器或临时环境变量传递。

## 4. 触发构建

**只有手动触发**（有意去掉了 `push` 自动触发，避免首推就跑几十分钟的 QEMU 构建、并过早定型包名）：

仓库 → Actions → `Build image to GHCR` → `Run workflow`，填：

| 输入 | 默认 | 说明 |
|---|---|---|
| `image_name` | `sun-panel` | 包名，**首次构建后不可改** |
| `tag` | `latest` | 镜像 tag |
| `platforms` | `linux/amd64,linux/arm64` | 只想快速验证可填 `linux/amd64` |

流程：checkout → 记录 `SOURCE_SHA` / `APP_VERSION` → QEMU → buildx → 登录 GHCR → 构建并推送。以后要重新出包，同样手动触发即可；改了代码想自动构建，再自行加回 `push` 触发。

## 5. 验证

```bash
# 公开包可直接拉取；若为 PRIVATE，需 docker login ghcr.io（PAT 要 read:packages）
docker pull ghcr.io/a454735639-lab/sun-panel:latest
docker image inspect ghcr.io/a454735639-lab/sun-panel:latest \
  --format '{{.Os}}/{{.Architecture}} {{.Config.Cmd}}'
```

在仓库右侧 `Packages` 或 `https://github.com/a454735639-lab?tab=packages` 查看包与可见性。

## 6. 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| `Permission denied (publickey)` / 403 | 回到第 1 节，确认 `permissions.push=true` |
| `refusing to allow a PAT to create or update workflow` | fine-grained PAT 缺 `Workflows: Read & Write`，或换 classic PAT |
| 提示包名大写非法 | workflow 已小写化；手填 `image_name` 时确认全小写 |
| `permission_denied: write_package` | 包由别的仓库创建，或仓库删后重建换了 repo id；换全新包名首推 |
| `installation not allowed to Create organization package` | 仓库被设成私有；改公开，或用带 `write:packages` 的 classic PAT |
| arm64 构建超时 | QEMU 编译 Go + CGO 慢；先只构建 `linux/amd64` 试通 |
| `pnpm` 报 frozen-lockfile | 确认 Dockerfile 仍是 `pnpm@8`；`pnpm-lock.yaml` 是 lockfileVersion 6.0 |
| `go-sqlite3` 编译失败 | 确认 builder 仍是 `golang:1.21-alpine3.18` |
| 前端构建报 Node 语法错 | 确认 `node:18-bookworm`，别用 `node:latest` / Node 20+ |

补充：classic PAT 需显式勾 `read:packages` / `write:packages` / `delete:packages`，`repo` scope 不覆盖；fine-grained token 对 GHCR 容器包不生效。仅在本地 `docker login ghcr.io` 拉私有包时才用得到 PAT，CI 里不需要。

## 7. 预期结果

得到 `linux/amd64` + `linux/arm64` 的**社区版**镜像。它是 2024 年开源快照，没有 Pro / Docker 管理等闭源模块，前端资源与后端依赖都和 `hslr/sun-panel:latest` 不同。详见 `REPO_NOTES.md`。

如果目标是"和原 tar 一样"，这一步不需要做——直接用原 tar，或用 `../01-slim-image/` 的派生包。
