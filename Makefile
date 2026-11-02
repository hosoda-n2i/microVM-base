# VM（Docker Sandboxes）を作る・入る・止める・消すための入口。このフォルダで打つ
# NAME を省くと forge-agent（sbxenv.yaml の name と同じ）。ほかの VM は make shell NAME=名前 のように指定する
NAME ?= forge-agent

# cmux の中で打ったときだけ、VM に入っている間のワークスペースをマゼンタにして「VM: 名前」を出す
IN_CMUX = [ -n "$$CMUX_WORKSPACE_ID" ] && command -v cmux >/dev/null 2>&1

.PHONY: help up shell stop rm ls

help:
	@echo "make up    [NAME=...]  sbxenv.yaml から VM を作る（初回は計画と鍵の承認を聞かれる）"
	@echo "make shell [NAME=...]  VM のシェルに入る（止まっていれば起動する）"
	@echo "make stop  [NAME=...]  VM を止める（中身は残る）"
	@echo "make rm    [NAME=...]  VM を消す（中身も消える）"
	@echo "make ls                VM の一覧"

up:
	sbx env create --name $(NAME)

shell:
	@if $(IN_CMUX); then \
	  cmux workspace-action set-color Magenta >/dev/null; \
	  cmux set-status vm "VM: $(NAME)" --icon shippingbox --color "#C026D3" --priority 100 >/dev/null; \
	fi; \
	sbx exec -it $(NAME) bash; status=$$?; \
	if $(IN_CMUX); then \
	  cmux clear-status vm >/dev/null; \
	  cmux workspace-action clear-color >/dev/null; \
	fi; \
	exit $$status

stop:
	sbx stop $(NAME)

rm:
	sbx rm $(NAME)

ls:
	sbx ls
