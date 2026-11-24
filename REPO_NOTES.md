# 可构建源码仓库说明

## 这是什么

一份**可以直接 push 到 https://github.com/a454735639-lab/sunpanel 并用 GitHub Actions 构建镜像**的社区版源码树。共 358 个文件（上游工作树 355 个 + 本次新增 3 个），Dockerfile 在仓库根目录，workflow 在 `.github/workflows/build-ghcr.yml`。

来源与许可：

| 项 | 值 |
|---|---|
| 上游仓库 | https://github.com/hslr-s/sun-panel（**不是** `hslr/sun-panel`，后者 404） |
| 快照 | `25f46209`（2024-04-26），当时 `v1.8.1` tag 也指向它 |
| 许可证 | MIT，根目录 `LICENSE` 与源码内版权声明原样保留 |
| 前端标称版本 | `service/assets/version` = `10\|1.3.0`（开源最后一版 1.3.0） |

**本目录只包含 MIT 开源源码，不包含从闭源镜像里抽出的 `/app/web` 编译产物，也不包含任何修改版二进制或授权相关代码。** 因此公开上传到 GitHub 没有额外的许可风险。

## 相对 `F:/开发区/sun-panel-buildable` 的改动

`04-buildable-repo/` 是那份已修好构建链的干净工作树（排除了 `.git`）。我只做了 4 处改动：

1. **新增** `.github/workflows/build-ghcr.yml` —— 面向新空仓库、默认分支 `main`、GHCR、QEMU + buildx 多架构；**仅 `workflow_dispatch` 手动触发**（首推源码不会自动构建），包名通过 `image_name` 输入配置（默认 `sun-panel`），owner/包名自动小写化。
2. **改** `Dockerfile`：`FROM alpine` → `FROM alpine:3.18`（浮动 tag 不可复现）。
3. **改** `Dockerfile`：`CMD ./sun-panel` → `CMD ["/app/sun-panel"]`（去 shell PID 1，与瘦身包对齐）。
4. **新增** 本文与 `PUSH_GUIDE.md`。

`Dockerfile` 里原有的两处关键修复保持不动：`node:18-bookworm` + `pnpm@8`（`pnpm-lock.yaml` 是 lockfileVersion 6.0，vite 4 / vue-tsc 1.2 与新版 Node 不兼容），以及 `golang:1.21-alpine3.18`（新版 alpine 会让 `mattn/go-sqlite3` 编译失败）。

仓库自带的 `.github/workflows/docker-build-push*.yml` 是上游原始 DockerHub CI，需要 `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` secrets 和 `DOCKER_IMAGE_NAME` variable，且只支持手动触发。它们不会自动运行；如不需要可以删掉。

## 与 `hslr_sun-panel-nopro(latest).tar` 的差异（重要）

| 项 | 本仓库构建结果 | 你手上的镜像 |
|---|---|---|
| 源码年代 | 2024-04-26 开源快照 | 2025-12-31 闭源 / Pro 版本 |
| 后端依赖 | `gopsutil/v3`、`x/crypto v0.8.0`，无 Docker 管理 | `docker/docker v25.0.6`、`gopsutil/v4`、`x/crypto v0.23.0` |
| Pro 授权模块 | **无** | 有 `ProAuthType` / `ProAuthApi` / `RenewTempAuth` 等符号 |
| Go 构建 | Go 1.21 + CGO，`ISDOCKER=docker` | Go 1.21.10 + CGO，`ISDOCKER=true` |
| 前端 | 由 `src/` 现场编译，产物哈希完全不同 | 固定的 `assets/index-DX9iIPV8.js` 等，版本串 `20251231-0342` |
| 基础镜像 | `alpine:3.18`（按 workflow 可出 amd64 + arm64） | `alpine-minirootfs-3.23.2-aarch64`（仅 arm64） |
| 构建时初始化 | `./sun-panel -config` | `./sun-panel -config-reset` |
| 启动命令 | 本仓库已改 exec 形式 | 原包 `/bin/sh -c ./sun-panel`；01 瘦身包已改 |
| 镜像层摘要 | 全新 | 固定 5 层 digest |

**结论**：这套源码能构建出一个能跑的社区版 sun-panel，但**不是**你手上那个镜像的等价源码，功能、前端资源、依赖、层摘要、tag 都不一样。要字节级一致的镜像，直接用原 tar，不要从源码重建。

## 已知限制

- 本机没有 docker，**没有实跑构建**。已做静态检查：Dockerfile 结构、workflow YAML 可解析、`service/assets/version` 存在、`pnpm-lock.yaml` 为 v6、`add-frontend-version.js` 与构建脚本齐全。首次请在 Actions 日志里确认。
- QEMU 模拟 arm64 编译 Go + CGO sqlite3 会比较慢（workflow 超时设了 180 分钟）。若只需要 amd64，手动触发时把 `platforms` 填 `linux/amd64`。
- 上游 workflow 引用的 `go install ...@latest` 未固定版本，长期看存在上游漂移风险；本次未改动（避免引入未经验证的版本号）。
- `.dockerignore` 里 `.*` 会排除 `.npmrc` 等点文件（仅 `!.env` 放行）。这是上游原样行为；若安装阶段出问题，先检查这里。
- 本仓库不提供、也不包含任何绕过授权的实现。
