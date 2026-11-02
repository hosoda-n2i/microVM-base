# syntax=docker/dockerfile:1
# プロジェクトごとのファイルを置く。最後の段（scratch）に置いたファイルだけが VM に重なる。

FROM debian:trixie-slim AS build
# project.yaml の workspace_folders（カンマ区切り）のフォルダを、ワークスペースの下に作る。
# 親のフォルダも層に入るので、持ち主（1000 = agent）と権限（0755）を workload と同じにしておく
ARG WORKSPACE_FOLDERS=""
RUN set -e \
 && ws=/out/home/agent/workspace \
 && install -d -o 1000 -g 1000 -m 0755 /out/home/agent "$ws" \
 && printf '%s\n' "$WORKSPACE_FOLDERS" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | while IFS= read -r name; do \
      case "$name" in \
        '') ;; \
        */*|.|..) echo "skip: $name" >&2 ;; \
        *) install -d -o 1000 -g 1000 -m 0755 "$ws/$name" ;; \
      esac; \
    done

FROM scratch
COPY --from=build /out/ /
