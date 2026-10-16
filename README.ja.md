# cobol.nvim

Neovim 向けの COBOL 編集サポート：固定形式の桁定規、定義と Copybook のナビゲーション、Tree-sitter による構造ヒント、レコード長の見積もり、任意の補完、GnuCOBOL 診断。COBOL の言語サーバーは不要です。

[English](README.md) · [简体中文](README.zh-CN.md) · Neovim ヘルプ：`:help cobol.nvim`

![固定形式の桁定規、Winbar パンくず、カーソル行のレコード長](assets/fixed-format-ruler.png)

スクリーンショットは固定形式プログラムでの動作例です。7/8/12/73 列の桁定規、Winbar のパンくず（`DATA DIVISION`）、カーソル行に表示されるレコード長の見積もりが見えます。テーマとレイアウトは各自の Neovim 設定によります。

## 機能一覧

| 分類 | 内容 | スクリーンショット |
| --- | --- | --- |
| 固定形式レイアウト | 7・8・12・73 列の桁定規、列ジャンプ、72 列超えのハイライト | 上記 |
| 構造アウトライン | アウトラインサイドバーの Division / Section / Paragraph / 制御構造 / データ階層ツリー | [下記](#構造アウトラインとスコープ表示) |
| 定義と Copybook の移動 | `gd`、`gf`、`K` プレビュー、ジャンプリスト | [下記](#定義と-copybook-の移動) |
| レコード長の計算 | `:CobolCalcRecord` による DISPLAY / COMP / COMP-3 / OCCURS / REDEFINES の一覧 | [下記](#pic-とレコード長の計算) |
| 診断 | 非同期 `cobc -fsyntax-only`、行内表示と Quickfix | [下記](#診断) |
| 折りたたみと整形 | Division / Section / Paragraph / データ項目単位の折りたたみ、予約語の大文字化 | [下記](#折りたたみと整形) |

## 対象

固定形式 COBOL を学ぶ初学者、`.cob` / `.cbl` / `.cobol` プログラムを保守する開発者、Copybook と伝統的な Division / Section / Paragraph 構造を使うプロジェクト。

## 必要な環境

- Neovim 0.10 以降。
- 同梱の Tree-sitter パーサーを**ビルド**するには C コンパイラ（`gcc`、`clang`、`cc`）が必要です。起動時に不足しているパーサーのコンパイルを試みます。AST 機能にはパーサーが必要ですが、`cobol.so` があれば実行時にコンパイラは不要です。
- 任意：[blink.cmp](https://github.com/saghen/blink.cmp)（補完）、GnuCOBOL（`cobc`、診断とビルド・実行）、Aerial または Syms（アウトラインサイドバー）。

## インストール

[lazy.nvim](https://github.com/folke/lazy.nvim) の場合：

```lua
{
  "iamcheyan/cobol.nvim",
  build = "bash scripts/build_parser.sh", -- 任意：インストール時に Tree-sitter パーサーをビルド
  ft = { "cobol", "cbl", "cob" },
  opts = {},
}
```

`build` フックがなくても、起動時に不足しているパーサーのコンパイルを試みます。C コンパイラが無い場合は、導入後に `./scripts/build_parser.sh` を一度実行してください。

任意のアウトラインサイドバーを使うには、Aerial を導入して COBOL バックエンドを有効にします：

```lua
{
  "stevearc/aerial.nvim",
  opts = function(_, opts)
    opts.backends = vim.tbl_deep_extend("force", opts.backends or {}, {
      cobol = { "cobol" },
    })
  end,
}
```

アウトラインのキーマップは既定では設定されません。必要なら自分で設定します：

```lua
vim.keymap.set("n", "<leader>cs", "<cmd>AerialToggle<CR>", { desc = "Toggle outline" })
```

プラグインは `cobol`、`cbl`、`cob` の filetype にアタッチします。認識されない `.cpy` は `:set filetype?` で確認し、必要なら `cobol` に設定してください。

## 最初のワークフロー

以下を**固定形式**の `.cob` ファイルとして保存します。行頭の空白はソース形式の一部です：

```cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEMO.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-STATUS PIC X VALUE "Y".
       PROCEDURE DIVISION.
           IF WS-STATUS = "Y"
               DISPLAY "READY"
           END-IF.
           STOP RUN.
```

1. ファイルを開いて桁定規を確認します。`g8`、`g12` で Area A / Area B に移動できます。
2. `WS-STATUS` の上で `gd`、`<C-o>` で戻ります。`IF` または `END-IF` の上で `%` を押すと対応するキーワードへ移動します。
3. `01` 項目で `:CobolCalcRecord` を実行します。`cobc` があれば `:CobolLint`、続けて `:CobolQuickfix` を使います。`za` で現在の Division / Section / Paragraph / データ項目を折りたたみます。

## 固定形式と編集

固定形式では 1〜6 列が連番領域、7 列が表示領域（`*` コメント、`/` 改ページ、`-` 継続行）、8〜11 列が Area A、12〜72 列が Area B、73 列以降が識別領域です。プラグインは 7・8・12・73 列に細い定規を描き、72 列を超えた文字列をハイライトします（固定形式のコンパイラはこの領域を無視します）。

| キー | 移動先 |
| --- | --- |
| `g7` | 表示領域 |
| `g8` | Area A |
| `g12` | Area B |
| `g73` | 識別領域 |

固定形式では、カーソル前が空白のみのとき Insert モードの `<Tab>` が 7・8・12 列に順に停まり、その後は `shiftwidth` でインデントします。`<S-Tab>` は逆順に停まり、ソース本文は削除しません。自由形式には列ストップはありません。

`:CobolGuideToggle` は視覚ヒントと診断のアタッチを切り替え、`:CobolGuideEnable` / `:CobolGuideDisable` は再アタッチ／解除します（解除時は現在の診断も消去）。既存のマッピングと折りたたみ設定はそのままです。

`gcc`、ビジュアルモードの `gc`、`<leader>c*`、`:CobolToggleComment` は検出したソース形式に従ってコメントを切り替えます（固定形式は 7 列の `*`、自由形式は `*>`）。コマンドは行範囲を指定できます。`:CobolFormatCase` は予約語を大文字化し、文字列・コメント・ユーザー定義名は保持します。範囲を指定しない場合はバッファ全体を処理します。

## 構造アウトラインとスコープ表示

![Aerial アウトライン、固定形式の桁定規、Winbar パンくず](assets/outline-aerial.png)

アウトラインサイドバーは任意です（Aerial または Syms）。プラグインは Aerial 用の COBOL バックエンドを同梱しています。バックエンドは Division、Section、Paragraph、プログラム ID、FD/SD、01 レベルのレコードを認識し、パーサーがあれば制御構造、分岐、ファイル操作、呼び出し、埋め込み SQL も扱います。アウトラインを導入しなくても他の機能は動作します。

![対になった IF / ELSE / END-IF のスコープバッジとアウトラインサイドバー](assets/image-20261016-111954.png)

上のキャプチャではアウトラインに Syms を使っています（Aerial でも Syms でも動作します）。エディタでは現在の `IF ... ELSE ... END-IF` ブロックが色付きの開始・分岐・終了バッジと縦の破線で示され、Winbar に構造のパンくずが表示されます。

パーサーがあると、カーソル位置の**最も内側の対になった構造**に、色付きの開始・終了バッジ、破線の接続線、`ELSE` / `WHEN` の分岐バッジを描画します。対応する組には `IF`、`EVALUATE`、`PERFORM`、`SEARCH`、`READ`、`WRITE`、`REWRITE`、`DELETE`、`START`、`STRING`、`UNSTRING`、および `XML PARSE`、`JSON PARSE`、`EXEC SQL`、`CLASS-ID`、`METHOD-ID`、`FACTORY`、`OBJECT` が含まれます。

設定：

```lua
structure_scope = { enable = true, char = "┆", show_branches = true }
```

Winbar のパンくずは `Division > Section > Paragraph > 制御構造 > WHEN` を表示します。完全な階層は `:lua require("cobol.ast").show_breadcrumb_float()` で確認できます。`:CobolStructure` はカーソル位置で期待される `END-*` キーワードを内側から順に通知し、フロート表示は `:lua require("cobol.ast").show_waiting_closures_float()` です。これは**終端キーワードの欠落チェッカーではありません**（対にできないブロックは通常表示されません）。構文確認には `:CobolLint` を使ってください。

`%` は上記構造の開始キーワードと終了キーワードの間を双方向に移動し、一致がなければ Neovim の既定動作にフォールバックします。テキストオブジェクト `af`/`if`、`ae`/`ie`、`ap`/`ip` は `IF`、`EVALUATE`、`PERFORM` ブロックの内部／全体を選択します（`vaf`、`daf` など）。

## 定義と Copybook の移動

![`K` で Copybook をフロート表示](assets/copybook-preview.png)

- `gd` / `:CobolGotoDef`：現在のファイルと再帰的に参照される Copybook を検索します。同名候補が複数ある場合は選択できます。
- `gf` / `:CobolGotoCopybook`：`COPY` 文が参照するファイルを開きます。
- `K` / `:CobolPreview`：定義や Copybook をフロートウィンドウでプレビューします（上図）。
- `<C-o>` / `<C-i>`：Neovim のジャンプリストを前後に移動します。

パスは `copybook_paths` またはプロジェクトプロファイルから取得し、言語サーバーは使いません。固定形式の列プレフィックスを持たない自由形式の宣言は現在の定義インデックスで見つからないことがあるため、見つからない場合はソース形式と検索パスを確認してください。

## PIC とレコード長の計算

![`:CobolCalcRecord` がオフセット、PIC、サイズ、合計を表示](assets/record-layout.png)

`<leader>cr` または `:CobolCalcRecord` は、現在のレコード／項目のレイアウト表を開き、一般的な `DISPLAY`、`COMP`/`BINARY`、`COMP-3`/`PACKED-DECIMAL`、`OCCURS`、`REDEFINES` のサイズを見積もります（上図）。

これらの値は一般的な GnuCOBOL とプラットフォームの慣例に基づく**見積もり**です。実際の ABI と格納レイアウトはコンパイラが正となります。特に、グループレベルの `OCCURS` は下位項目の合計に重複計上されず、より大きい `REDEFINES` の上書きも合計を増やしません。表示される合計長はその前提で読んでください。

## 診断

![保存後にコンパイラエラーが行内に表示される](assets/diagnostics.png)

プラグインは次を実行します：

```text
cobc -fsyntax-only ...
```

保存後、テキスト変更のデバウンス後、Insert モードを抜けたときに非同期で実行します。`<leader>cl` または `:CobolLint` で即時実行、`<leader>cq` または `:CobolQuickfix` で Quickfix リストを開き、`:CobolDiagnosticsToggle` で自動診断を切り替えます。未保存の内容は可能な限り標準入力経由でコンパイラに渡します。`cobc` が無くてもプラグインは落ちません。GnuCOBOL を導入するか `cobc_command` を設定してください。

## 折りたたみと整形

![Division・Section・Paragraph 単位で折りたたむ](assets/folding.png)

Division、Section、Paragraph、データ項目のネイティブ折りたたみを提供します。`za` で切り替え、`zc` で閉じ、`zo` で開きます（上図）。`IF`/`EVALUATE` などの制御構造の折りたたみは他の折りたたみ提供元によるもので、存在する場合は生の行数ではなく構造サマリーを表示できます。

`folding.foldtext` が折りたたみテキストの所有権を決めます：

| 値 | 動作 |
| --- | --- |
| `"auto"`（既定） | nvim-ufo が管理していない限り COBOL のサマリーを設定します。 |
| `"plugin"` | 常に COBOL 構造のサマリーを使います。 |
| `"off"` | `foldtext` に触れません。 |

固定形式のバッファは一般的なブロックとデータレベルに COBOL 対応のインデントを使います。`gg=G` で全体、ビジュアルモードの `=` で選択範囲を整形します。連番／表示領域の行、継続行、コメント、73〜80 列の非空テキストは保持されます。

## 補完

`blink.cmp` を導入すると、`cobol`、`cbl`、`cob` バッファ向けに補完ソースを登録します。一般的な動詞と句、`IF ... END-IF` や `PERFORM ... END-PERFORM` のような展開可能なスニペット、バッファ内で宣言された名前、参照 Copybook のシンボルを候補にします。大文字小文字は区別せず、`PER`、`WS-`、`COPY` などの接頭辞を入力したときに特に有用です。補完は任意で、無くても他の機能は動作します。

## プロジェクト設定

プロジェクトルートに `.cobol.json` を作成します：

```json
{
  "source_format": "fixed",
  "dialect": "default",
  "compiler": "cobc",
  "copybook_paths": ["copy", "cpy"],
  "warnings": ["all", "no-obsolete"],
  "compiler_args": ["-Wall"],
  "commands": {
    "build": ["make", "build"],
    "run": ["make", "run"],
    "test": ["make", "test"]
  }
}
```

相対パスは検出したプロジェクトルートから解決し、ナビゲーション、補完、診断、単一ファイルのビルドが同じ Copybook パス、コンパイラ、形式、方言、追加引数を共有します。プロファイルは任意で、`.cobol.json` が無ければ既定値を静かに使います。JSON やフィールドが不正な場合は警告し、安全な既定値にフォールバックします。コマンド値は引数配列で、**シェルを経由しません**。コマンドを明示しない場合、Makefile の `build`/`all`、`run`、`test`/`check` を認識します。Makefile の無い単一ソースは `cobc` にフォールバックします。プロジェクトコマンドの実行前にバッファを保存してください。

`:CobolBuild`、`:CobolRun`、`:CobolTest` は非同期で実行し、コンパイラの位置を Quickfix リストに登録します（`:cnext`、`:cprev`）。

## コマンド

| コマンド | 用途 |
| --- | --- |
| `:CobolGuideToggle` | 視覚ヒントと診断のアタッチを切り替え |
| `:CobolGuideEnable` / `:CobolGuideDisable` | ヒントと診断を再アタッチ／解除 |
| `:CobolToggleComment` | ソース形式に応じてコメントを切り替え（範囲指定可） |
| `:CobolGotoDef` | 定義へ移動 |
| `:CobolGotoCopybook` | Copybook を開く |
| `:CobolPreview` | 段落または Copybook をプレビュー |
| `:CobolCalcRecord` | レコードレイアウトの見積もりを表示 |
| `:CobolStructure` | カーソル位置で期待される `END-*` を通知 |
| `:CobolFormatCase` | 認識した予約語を整形 |
| `:CobolLint` | GnuCOBOL の構文チェックを実行 |
| `:CobolQuickfix` | 診断の Quickfix リストを開く |
| `:CobolDiagnosticsToggle` | 自動診断を切り替え |
| `:CobolBuild` / `:CobolRun` / `:CobolTest` | ビルド／実行／テスト |

## 設定項目

既定値は小規模なプロジェクト向けです。プロジェクト固有の設定例：

```lua
{
  "iamcheyan/cobol.nvim",
  ft = { "cobol", "cbl", "cob" },
  opts = {
    project_root = vim.fn.expand("~/src/my-cobol-project"),
    copybook_paths = { ".", "./cpy", "./copybooks", "./include" },
    cobc_command = "cobc",
    cobc_extra_args = {},
    source_format = "auto",
    structure_scope = { enable = true, char = "┆", show_branches = true },
    folding = { enable = true, foldtext = "auto" },
    diagnostics = { enable = true, debounce_ms = 600 },
  },
}
```

その他のオプションには `show_hierarchy_hint`、`show_pic_size`、`highlight_levels`、`show_colorcolumn`、`disable_indent_guide`、`diagnostics.on_save`/`on_change`、`diagnostics.warnings`/`dialect`、`completion.enable` があります。既定値は `:help cobol-configuration` を参照してください。ソース上で宣言されている `enabled`、`overflow_col`、`smart_comments` は現在それぞれの動作を制御していないため、スイッチとして使わないでください。

## トラブルシューティング

- **桁定規やマッピングが出ない**：`:set filetype?`、`:verbose nmap gd`、`keymaps` を確認します。
- **スコープバッジ、パンくず、`%` が動かない**：Tree-sitter パーサーがありません。C コンパイラを導入するか `./scripts/build_parser.sh` で `cobol.so` をビルドしてください。
- **アウトラインが出ない**：サイドバーは任意のアウトラインプラグイン（Aerial または Syms）が提供します。導入して設定してください。
- **診断が出ない**：`:echo executable('cobc')` と `cobc_command` を確認します。
- **Copybook が見つからない**：`project_root` を設定し、ディレクトリを `copybook_paths` に追加します。
- **レイアウト長が想定と違う**：計算結果は見積もりとして扱い、コンパイラで確認してください。

## 開発

リポジトリのルートでテストを実行します：

```bash
./scripts/test.sh
```

Aerial 固有のテストは Aerial が無い場合スキップされます。コアのテストは Aerial を必要としません。

## ライセンス

MIT。[LICENSE](LICENSE) を参照してください。
