# syntax=docker/dockerfile:1
# workload に足す道具。最後の段（scratch）に置いたファイルだけが、
# Claude Code の workload の上に重なる。

FROM debian:trixie-slim AS build
ARG GH_VERSION
ARG VOLTA_VERSION
ARG DIRENV_VERSION
ARG TARGETARCH
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/gh
# GitHub CLI：公式のリリースを取り、チェックサムを確かめてから置く
RUN base="https://github.com/cli/cli/releases/download/v${GH_VERSION}" \
 && file="gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && curl -fsSLO "${base}/${file}" \
 && curl -fsSL "${base}/gh_${GH_VERSION}_checksums.txt" | grep " ${file}\$" | sha256sum -c - \
 && tar -xzf "${file}" \
 && mkdir -p /out/usr/local/bin \
 && install -m 0755 "gh_${GH_VERSION}_linux_${TARGETARCH}/bin/gh" /out/usr/local/bin/gh

WORKDIR /tmp/volta
# Volta：公式のリリースを取り、本体を /usr/local/bin に置く。
# node・npm・npx の入口（shim）は ~/.volta/bin に作る（dev-tools.yaml の install）。
# shim を ~/.volta/bin 以外に置くと、版の指定が無いときに Volta が自分自身を呼び続ける
RUN case "${TARGETARCH}" in \
      amd64) asset="volta-${VOLTA_VERSION}-linux.tar.gz" ;; \
      arm64) asset="volta-${VOLTA_VERSION}-linux-arm.tar.gz" ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && curl -fsSL "https://github.com/volta-cli/volta/releases/download/v${VOLTA_VERSION}/${asset}" | tar -xz \
 && mkdir -p /out/usr/local/bin \
 && install -m 0755 volta volta-shim volta-migrate /out/usr/local/bin/

# direnv：公式のリリースの1ファイルを置く（direnv はチェックサムのファイルを出していない）
RUN curl -fsSL -o /out/usr/local/bin/direnv "https://github.com/direnv/direnv/releases/download/v${DIRENV_VERSION}/direnv.linux-${TARGETARCH}" \
 && chmod 0755 /out/usr/local/bin/direnv

# 中の Claude に渡す説明。install で /home/agent/workspace/CLAUDE.md に写す（dev-tools.yaml）
COPY context.md /out/usr/share/dev-tools/CLAUDE.md

# 道具を足すときは、上の build の段で /out の下に置く
FROM scratch
COPY --from=build /out/ /
