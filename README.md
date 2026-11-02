# microVM-base

Docker Sandboxes（sbx）の microVM を作るための設定です。Docker 公式の Claude Code の環境に、開発でよく使う道具（Kit：dev-tools）を足して作ります。作業するプロジェクトは、VM の中で clone します。

## はじめに（Mac で 1回だけ）

```sh
brew install docker/tap/sbx
sbx login
sbx policy init balanced
sbx secret set github   # GitHub を使うなら。対象のリポジトリだけに絞ったトークンを貼る
```

## 使い方

このフォルダで打ちます。

```sh
make up        # VM を作る
make shell     # VM のシェルに入る
make stop      # 止める（中身は残る）
make rm        # 消す（中身も消える）
make ls        # VM の一覧
```

- VM の名前は `forge-agent` です。ほかの名前にするときは `NAME=名前` を付けます（`make shell NAME=名前`）
- 初回の `make up` で、Kit が鍵を使ってよいかを聞かれるので承認します
- Claude Code を使うときは、VM の中で `claude` を打ちます。初回は `/login` します

## VM の中身

- 作業場所：`/home/agent/workspace`。中の AI への説明（`kits/dev-tools/context.md`）が、ここに `CLAUDE.md` として置かれます
- ワークスペースの下にフォルダを作るときは、`kits/project/project.yaml` の `workspace_folders` にフォルダ名をカンマで区切って書きます（例：`"app,docs"`）。プロジェクトだけで使う設定は、この `kits/project` に置きます
- 道具：Claude Code（起動のたびに最新に更新）、gh、git、Docker、Node.js（Volta）、direnv、Python、Go、jq、ripgrep など
- 入っていない：pnpm、PHP、mysql のクライアント、vim。uv は入っているが動かない
- Mac のフォルダと SSH の鍵は、VM に渡しません

## 道具を足す

- `kits/dev-tools/dev-tools.dockerfile` の build の段で、`/out` の下に置きます
- ネットにつなぐ道具なら、`kits/dev-tools/dev-tools.yaml` の `allow` に宛先を足します
- 変えたら `make rm` → `make up` で作り直します

## 気をつけること

- ホストのリポジトリを VM にマウントしないでください。中の AI が `.git/hooks` を書き換えると、Mac で `git commit` したときに動きます
- balanced の設定では、`**.googleapis.com` など広い宛先にも通信できます。絞るなら `sbx policy reset` のあと `sbx policy init deny-all` にして、要る宛先だけを `sbx policy allow` で足します
- 差し込んだ GitHub のトークンでできることは、中の AI もできます。トークンの権限を絞ってください

## 参考

- [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)
- [Kit の仕様（docker/sandbox-kit-spec）](https://github.com/docker/sandbox-kit-spec)
