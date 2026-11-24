# build frontend
# 固定 Node 18 与 pnpm 8：pnpm-lock.yaml 为 lockfileVersion 6.0（由 pnpm 8 生成），
# 且 vite 4 / vue-tsc 1.2 与新版 Node 不兼容。上游原为未固定版本的 `FROM node`
# 与 `npm install pnpm -g`，在较新的构建环境中会因 frozen-lockfile 或语法问题失败。
FROM node:18-bookworm AS web_image

# 华为源
# RUN npm config set registry https://repo.huaweicloud.com/repository/npm/

RUN npm install -g pnpm@8

WORKDIR /build

COPY ./package.json /build

COPY ./pnpm-lock.yaml /build

RUN pnpm install

COPY . /build

RUN pnpm run build

# build backend
# 最新alpine3.19导致sqlite3编译失败(https://github.com/mattn/go-sqlite3/issues/1164，
# 临时解决方案:https://github.com/mattn/go-sqlite3/pull/1177)
# sun-panel暂时解决方案使用golang:1.21-alpine3.18（因旧版本使用没问题，短期内较稳定） 
FROM golang:1.21-alpine3.18 as server_image

WORKDIR /build

COPY ./service .

# 中国国内源
# RUN sed -i "s@dl-cdn.alpinelinux.org@mirrors.aliyun.com@g" /etc/apk/repositories \
#     && go env -w GOPROXY=https://goproxy.cn,direct

RUN apk add --no-cache bash curl gcc git musl-dev

RUN go env -w GO111MODULE=on \
    && export PATH=$PATH:/go/bin \
    && go install -a -v github.com/go-bindata/go-bindata/...@latest \
    && go install -a -v github.com/elazarl/go-bindata-assetfs/...@latest \
    && go-bindata-assetfs -o=assets/bindata.go -pkg=assets assets/... \
    && go build -o sun-panel --ldflags="-X sun-panel/global.RUNCODE=release -X sun-panel/global.ISDOCKER=docker" main.go



# run_image
# 固定 alpine 版本：上游 `FROM alpine` 是浮动 tag，基础镜像一变，
# apk 包版本、层摘要、CGO 运行时都会跟着变，构建不可复现。
FROM alpine:3.18

WORKDIR /app

COPY --from=web_image /build/dist /app/web

COPY --from=server_image /build/sun-panel /app/sun-panel

# 中国国内源
# RUN sed -i "s@dl-cdn.alpinelinux.org@mirrors.aliyun.com@g" /etc/apk/repositories

EXPOSE 3002

RUN apk add --no-cache bash ca-certificates su-exec tzdata \
    && chmod +x ./sun-panel \
    && ./sun-panel -config

# exec 形式：让 Go 进程直接成为 PID 1，docker stop 时 SIGTERM 能送达，
# 不再由 /bin/sh 中转（与 01-slim-image 的行为对齐）。
CMD ["/app/sun-panel"]
