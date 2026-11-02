# Docker Sandboxes の動き

sbx 0.49.2（2026-10-23）で確かめた内容です。sbx は試験中の機能が多く、版が上がると変わることがあります。

## 全体の形

```mermaid
flowchart LR
  subgraph MAC["Mac"]
    U["端末<br>make up・make shell"]
    D["sbx のデーモン<br>VM を作る・管理する"]
    P["プロキシ<br>通信を許可するか決める<br>鍵を差し込む"]
    DK["Mac の Docker<br>Kit をビルドする"]
    U -->|"sbx のコマンド"| D
    D -->|"Kit のビルドを頼む"| DK
  end
  subgraph VM["microVM（1台）"]
    A["中の AI・道具<br>Claude Code・gh・git など"]
  end
  HUB[("Docker Hub<br>workload のイメージ")]
  NET[("外のサービス<br>api.anthropic.com・github.com など")]
  D -->|"作る・起動する"| VM
  HUB -->|"取得"| D
  A -->|"すべての外への通信"| P
  P -->|"許可した宛先だけ・鍵を付けて"| NET
```

- VM の外への通信は、すべて Mac のプロキシを通ります。許可していない宛先は止められます
- 鍵（トークン）はプロキシが通信に付けます。VM の中に本物の鍵は入りません

## VM の中身は Kit を重ねて作る

```mermaid
flowchart LR
  subgraph FS["VM の中の /（上の層ほど優先して見える）"]
    direction TB
    W["書き込み用の層<br>中で入れた物・作業したファイル。VM を消すと消える"]
    M["dev-tools の層（このリポジトリの Kit）<br>gh・Volta・CLAUDE.md の元"]
    B["docker/sbx-kit-claude の層（Docker の workload）<br>Debian・Claude Code・git・Docker・Node.js など"]
    W ~~~ M ~~~ B
  end
  subgraph DECL["宣言（ファイルには入らない。sbx が VM を作るときに当てる）"]
    direction TB
    D1["workload の宣言<br>Anthropic への通信・鍵・起動のしかた"]
    D2["dev-tools の宣言<br>GitHub・nodejs.org への通信・鍵・作るときと起動のときのコマンド"]
  end
  DECL -.->|"両方を合わせて当てる"| FS
```

- Kit には2種類あります。土台の workload（VM に1つだけ）と、上に重ねる mixin（いくつでも）です。dev-tools は mixin です
- Kit は「ファイルの層」と「宣言（YAML）」のセットです。宣言はイメージのファイルではなく、イメージの送り状（マニフェスト）の注釈 `vnd.docker.sandbox.kit.descriptor` に載ります
- そのため、Dockerfile の `FROM docker/sbx-kit-claude` で作り直すと、ファイルは受け継げても宣言は受け継げません。土台はコマンド（ここでは sbxenv.yaml の `kits`）で指定して重ねます
- 中身を見るには `sbx kit inspect docker.io/docker/sbx-kit-claude:latest` を打ちます

## Kit のビルド

```mermaid
flowchart LR
  Y["dev-tools.yaml<br>Kit の宣言"]
  subgraph DF["dev-tools.dockerfile"]
    direction TB
    S1["1段目 FROM debian<br>curl で gh・Volta を取ってくる作業場"]
    S2["2段目 FROM scratch<br>/out の中身だけを置く"]
    S1 -->|"/out だけを渡す"| S2
  end
  I["dev-tools のイメージ<br>層：gh・Volta・CLAUDE.md の元<br>注釈：YAML の宣言"]
  Y -->|"dockerfile: で指定<br>版を引数で渡す"| DF
  DF --> I
  Y -->|"宣言を注釈に入れる"| I
```

- ビルドは sbx が Mac の Docker に頼んで行います。自分で `docker build` する必要はありません
- 最後の段を `FROM scratch` にしているのは、Debian 一式が workload の上に重なって、ベースのファイルを上書きしないようにするためです
- `/home/agent` の下のファイルは、層には置かず、作るときのコマンドで置きます。層に置くと、`/home/agent` のフォルダの持ち主が上書きされるおそれがあるからです

## 作ってから使うまで

```mermaid
sequenceDiagram
  actor U as 端末（Mac）
  participant S as sbx
  participant DK as Mac の Docker
  participant H as Docker Hub
  participant V as microVM
  U->>S: make up（sbx env create）
  S->>U: 計画を見せて承認を求める
  U->>S: 承認
  S->>DK: dev-tools をビルド
  S->>H: workload（sbx-kit-claude:latest）を取得
  S->>U: Kit が鍵を使ってよいか聞く（承認は覚えておく）
  rect rgb(235, 245, 255)
  Note over S,V: 作るとき（1回だけ）
  S->>V: 層を重ねて VM を作る
  S->>V: 通信の許可・鍵を当てる
  S->>V: install のコマンド（Volta の入口・ワークスペースの CLAUDE.md）
  end
  rect rgb(240, 255, 240)
  Note over S,V: 起動するたび
  S->>V: startup のコマンド（裏で claude update）
  end
  U->>S: make shell（sbx exec -it 名前 bash）
  S->>V: 止まっていれば起動して、シェルをつなぐ
```

- 鍵を承認しないと、鍵が差し込まれないまま作られます。承認は `~/.config/sbx/credentials.yaml` に残ります
- install のコマンドは作るときに1回、startup のコマンドは起動のたびに動きます。startup の記録は VM の中の `/var/log/sbx-kit-startup.log` です

## 通信の許可と鍵

```mermaid
sequenceDiagram
  participant A as 中の AI・道具
  participant P as プロキシ（Mac）
  participant G as api.github.com
  A->>P: GET api.github.com（GH_TOKEN は仮の値）
  P->>P: 許可の一覧にある → 本物のトークンを付ける
  P->>G: Authorization: Bearer 本物のトークン
  G-->>A: 応答
  A->>P: http-intake.logs.us5.datadoghq.com
  rect rgb(255, 235, 235)
  P-->>A: 止める（No matching allow rule）
  end
```

- 許可の一覧は、Mac の全体の設定（`sbx policy init balanced` など）と、各 Kit の宣言を合わせたものです
- 止められた通信は `sbx policy log 名前` で見られます。例：Claude Code の利用統計の送り先（Datadog）は、どこにも許可がないので止められます
- 差し込んだトークンでできることは、中の AI もできます。トークンの権限を絞るのが、いちばん効く対策です

## 中の AI への説明（CLAUDE.md）

```mermaid
flowchart TB
  subgraph VM["VM の中"]
    C1["~/.claude/CLAUDE.md<br>sbx が作る。本文は Docker の説明<br>末尾に mixin の説明の案内だけが入る"]
    C2["~/workspace/CLAUDE.md<br>dev-tools の install が置く（中身は context.md）"]
    CL["ワークスペースで起動した Claude Code"]
  end
  C1 -->|"いつも読む"| CL
  C2 -->|"起動したフォルダか、その上にあるので<br>起動のときに必ず読む"| CL
```

- Kit の `agent-context@1` で説明を渡すと、mixin の説明は本文に入らず、案内の1行になります。読むかどうかは Claude 次第です
- 本文に入れる `agent-context@2` は、sbx 0.49.2 では「unsupported capability type」になり使えません
- そのため、dev-tools は context.md をワークスペースの `CLAUDE.md` として置いています

## Mac のフォルダの渡し方

```mermaid
flowchart LR
  GH[("GitHub")]
  MR["Mac のリポジトリ<br>作業ツリーと .git"]
  subgraph N["渡さない（このリポジトリの形）"]
    N1["VM の中のクローン"]
  end
  subgraph DM["そのままマウント"]
    D1["Mac と同じパスに見える"]
  end
  subgraph CM["--clone"]
    C0["/run/sandbox/source"]
    C1["VM の中のクローン"]
    C0 -->|"作るときに写す"| C1
  end
  GH -->|"VM の中で git clone"| N1
  MR <-->|"読み書き（.git/hooks も）"| D1
  MR -->|"読むだけ"| C0
```

- `sbx run` はパスを書かないと、今いるフォルダをマウントします。`sbx create`・`sbx env create`（`make up`）は、パスを書かなければマウントしません
- そのままマウントすると、中の AI が `.git/hooks` を書き換え、Mac で `git commit` したときにそれが動きます
- `--clone` でも、Mac のファイルは読めます。`.env` などの秘密は中から見えます

## 版の上がり方

- workload は `latest` を使っています。ただし `latest` は毎回更新されません（10/23 時点で `latest` は 2.1.291、最新のタグは 2.1.296）
- Claude Code 本体は、起動のたびに `claude update` で最新になります（`latest` の 2.1.291 から 2.1.309 に上がりました）。結果は VM の中の `/tmp/claude-update.log` です
- 組み込みの `sbx run claude` は、別の古い形のイメージ（`docker/sandbox-templates:claude-code-docker`）を使います。workload の Kit ではないので、dev-tools は重ねられません

## よく使うコマンド

```sh
sbx ls                                  # VM の一覧
sbx exec -it 名前 bash                   # VM のシェル（make shell と同じ）
sbx policy log 名前                      # 止められた通信・通った通信
sbx kit inspect docker.io/docker/sbx-kit-claude:latest   # Kit の宣言の中身
sbx env plan                            # make up で何が作られるか（作らない）
```

## 参考

- [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)
- [Kits](https://docs.docker.com/ai/sandboxes/customize/kits/)
- [Isolation（マウントの方式と危険）](https://docs.docker.com/ai/sandboxes/security/isolation/)
- [Kit の仕様 v3（docker/sandbox-kit-spec）](https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md)
