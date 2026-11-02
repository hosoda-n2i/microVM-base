# この環境について

Docker Sandboxes の microVM です。開発に使う道具を足してあります。

- `gh` は `/usr/local/bin/gh` にあります（この Kit で入れた版）。
- GitHub の認証はプロキシが行います。`GH_TOKEN` に入っているのは仮の値なので、表示・コピーしないでください。
- `gh auth login` は実行しないでください。Mac 側で GitHub の鍵が登録されていれば、認証はすでに通ります。
- GitHub の操作は、git より `gh`（`gh pr create`、`gh api` など）を優先してください。
- bash から使う `node`・`npm`・`npx` は Volta を通ります。package.json の `volta` に Node の版が書いてあるプロジェクトでは、その版が使われます（初回は nodejs.org から取得）。
- direnv が入っています。対話のシェルでは、`.envrc` のあるフォルダに入ると自動で読まれます。Bash ツールのような対話でないシェルでは読まれないので、`direnv exec . <コマンド>` で実行してください（初回は `direnv allow` が要ります）。
