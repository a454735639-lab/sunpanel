# 上游源码溯源与改动说明

## 来源

| 项 | 值 |
|---|---|
| 上游仓库 | https://github.com/hslr-s/sun-panel |
| Tag / 提交 | `v1.8.1` / `25f46209` (2024-04-26) |
| 许可证 | MIT，根目录 `LICENSE` 与源码内版权声明原样保留 |
| 导入提交 | `5e97d4c`（本分支基于 `main` 创建，共享历史） |

> 注意：`source/README.md` 中写的 `github.com/hslr/sun-panel` 是错误地址（404）。
> 镜像内 Go buildinfo 的模块名、依赖版本（gin v1.9.0、goquery v1.8.1、fatih/color v1.15.0）
> 以及 Dockerfile 的三阶段结构均与本分支一致。

## 本分支相对上游的改动

导入时 354 个文件与上游逐文件比对完全一致。之后仅修改了一个文件：

- `Dockerfile`
  - `FROM node` → `FROM node:18-bookworm`（上游未固定版本，新版 Node 无法构建 vite 4 / vue-tsc 1.2）
  - `RUN npm install pnpm -g` → `RUN npm install -g pnpm@8`（`pnpm-lock.yaml` 是 lockfileVersion 6.0，由 pnpm 8 生成；新版 pnpm 会因 frozen-lockfile 失败）

其余文件内容保持不变。仓库自带的 `.github/workflows/docker-build-push*.yml` 是上游原始 CI，
依赖 `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` secrets 和 `DOCKER_IMAGE_NAME` variable，
且只支持 `workflow_dispatch`（要求 workflow 位于默认分支），在本仓库中未启用。

## 如何构建镜像

### 本地

```bash
cd F:/开发区/sun-panel-buildable       # 或在任意有 Docker 的环境 clone 本分支
docker build -t sun-panel:local .
docker save sun-panel:local -o sun-panel-local.tar
```

### GitHub Actions（推荐，无需本机 Docker）

在仓库 Actions 页面运行 **Build image to GHCR**，或在默认分支的
`.github/workflows/build-ghcr.yml` 中查看参数。该 workflow 会 checkout 本分支、
用 QEMU + buildx 构建 amd64/arm64 镜像并推送到
`ghcr.io/a454735639-lab/sun-panel:<tag>`，使用内置 `GITHUB_TOKEN`，无需 Docker Hub 凭据。

参数：`platforms`（默认 `linux/amd64,linux/arm64`）、`tag`（默认 `latest`）、
`source_ref`（默认 `upstream-v1.8.1`）。

## 与本地 Docker 镜像的差异（重要）

本分支能构建出可运行的 **社区版** sun-panel 镜像，但**不等于** `F:/开发区/` 下那两份
`hslr_sun-panel*.tar`。镜像内二进制含 `biz.(*ProAuthType).ProIsExpired` 与
`github.com/docker/docker v25.0.6` 等依赖，公开源码中完全没有 Pro 授权模块。
若需要"去除 Pro 限制"的镜像，须走「源码构建原版 → 对产物二进制打补丁 → 重新打包」的链路；
该镜像架构为 arm64，补丁偏移与 x86_64 不同。

`main` 分支保存的是从镜像还原的资料文件（含补丁说明与反编译伪代码），
涉及软件授权合规，仓库保持 private，请勿直接公开分发。
