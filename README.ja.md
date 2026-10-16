# cobol.nvim

固定形式 COBOL の読解・編集を支援する Neovim プラグインです。列ガイド、定義と Copybook の検索、構造の可視化、レコードサイズの概算、補完、GnuCOBOL による診断を提供します。COBOL の言語サーバーは不要です。

[English](README.md) · [简体中文](README.zh-CN.md)

![Syms の構造アウトラインと IF/ELSE/END-IF のスコープ表示](assets/image-20261016-111954.png)

新しいスクリーンショットには、オプションの Syms アウトライン、固定形式の列ガイド、Winbar のパンくず、現在の `IF ... ELSE ... END-IF` に付く色付きの開始・分岐・終了マークと縦の破線が写っています。Syms はこの画面で使用している別のアウトライン UI です。本プラグインが同梱するアウトライン用バックエンドは Aerial 向けです。色や画面構成は利用者の Neovim 設定によって異なります。

以前の [Aerial と Copybook プレビューの画面](screenshot.png) も参照できます。

## 主な機能

| 分野 | 機能 |
| --- | --- |
| 固定形式 | 7、8、12、73 列のガイド、72 列を超える部分の強調、列へのジャンプ、Tab の列位置合わせ |
| 構造 | Tree-sitter によるパンくず、最も内側の対応するブロックの色付きマークと接続線、`%` による対応箇所への移動、テキストオブジェクト |
| 移動と編集 | `gd` による定義検索、`gf` による Copybook の表示、`K` によるプレビュー、コメント切り替え、予約語の大文字化 |
| データ | PIC とレコードサイズの概算、01/88 レベルの強調、親項目のヒント |
| 補完・アウトライン | 任意の blink.cmp 補完ソースと Aerial 用 COBOL バックエンド |
| 診断・実行 | 非同期の `cobc` 構文チェック、Quickfix、プロジェクトのビルド・実行・テスト |

## 必要条件とインストール

- Neovim 0.10 以降。
- Tree-sitter による構造表示には COBOL パーサーが必要です。パーサーがない場合、起動時に `gcc`、`clang`、`cc` のいずれかを使って自動ビルドを試みます。C コンパイラーがなく、ビルド済みパーサーも導入されていない場合は AST 機能を使えません。
- GnuCOBOL (`cobc`) は診断・ビルドに必要ですが、その他の編集機能には不要です。
- [blink.cmp](https://github.com/saghen/blink.cmp) と [Aerial](https://github.com/stevearc/aerial.nvim) は任意です。それぞれ補完メニューとアウトラインを提供します。

[lazy.nvim](https://github.com/folke/lazy.nvim) の設定例：

```lua
{
  "iamcheyan/cobol.nvim",
  build = "bash scripts/build_parser.sh", -- 任意：インストール時にパーサーをビルド
  ft = { "cobol", "cbl", "cob" },
  opts = {},
}
```

`build` を省略しても、C コンパイラーがあれば起動時にパーサーの自動ビルドを試みます。手動ビルドはリポジトリのルートで `./scripts/build_parser.sh` を実行してください。GnuCOBOL 自体は別途インストールします。

Aerial を使う場合は、Aerial 自体をインストールして COBOL バックエンドを指定します：

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

本プラグインにはアウトラインを開く既定のキーはありません。Aerial は `:AerialToggle` で切り替えられます。`<leader>cs` を使いたい場合は、自分の設定に `vim.keymap.set("n", "<leader>cs", "<cmd>AerialToggle<CR>")` を追加してください。Syms を使う場合は Syms 側で設定します。

## 最初の使い方

1. COBOL ファイルを開き、`:set filetype?` で `cobol`、`cbl` または `cob` を確認します。固定形式では 7 列目が指示領域、8–11 列が Area A、12–72 列が Area B、73 列目以降が識別領域です。
2. 段落名やデータ名の上で `gd`、`COPY` 文で `gf`、定義のプレビューには `K` を使います。`<C-o>` で元の位置に戻れます。
3. 01 レコードまたはフィールドで `<leader>cr` / `:CobolCalcRecord` を実行して概算のレイアウトを確認します。
4. GnuCOBOL がある場合は保存するか `<leader>cl` / `:CobolLint` で構文を検査します。`<leader>cq` / `:CobolQuickfix` で問題の一覧を開けます。
5. Division、Section、Paragraph、データ項目の折りたたみには `za`、`zc`、`zo` を使います。アウトラインは必要に応じて Aerial などを別途インストールします。

## 固定形式の編集と移動

列ガイドは `:CobolGuideToggle` で切り替えます。`:CobolGuideDisable` は表示と診断のアタッチを解除して現在の診断を消去しますが、既存のバッファー内キーマップや折りたたみ設定は削除しません。`:CobolGuideEnable` で再度アタッチします。ガイド切り替え用の既定のキーはありません。

| キー | 用途 |
| --- | --- |
| `g7` / `g8` / `g12` / `g73` | 固定形式の各列へ移動 |
| `gd` / `:CobolGotoDef` | 現在のファイルと再帰的に参照される Copybook の定義を検索し、同名なら候補を選択 |
| `gf` / `:CobolGotoCopybook` | `COPY` 文の Copybook を開く |
| `K` / `:CobolPreview` | 定義または Copybook を浮動ウィンドウに表示 |
| `gcc`、Visual `gc`、`<leader>c*` | 現在行または選択行のコメントを切り替え |

固定形式の Insert モードでカーソル前が空白のみの場合、`<Tab>` は 7、8、12 列の位置合わせを行い、以降は `shiftwidth` 分進みます。`<S-Tab>` は逆方向へ移動します。自由形式ではこの固定列用の動作は使いません。固定形式のコメントは 7 列目の `*`、自由形式は `*>` です。`:CobolToggleComment` は行範囲も受け付けます。

固定形式のインデントは一般的な制御ブロックやデータレベルを扱うヒューリスティックです。`gg=G` でファイル全体、Visual 選択後の `=` で一部を整形できます。連続行や方言固有の構文は、列位置とコンパイラーの結果を確認してください。詳しくは[中国語の固定形式ガイド](README.zh-CN.md#2-固定格式-tab-和智能缩进)を参照してください。

## Tree-sitter による構造表示

パーサーを利用できる場合、カーソルを含む**対応する終端を持つ最も内側のブロック**に焦点を当てます。開始・終了キーワードには深さごとに異なる背景色のマークを付け、間に縦の破線（既定では `┆`）を描きます。`ELSE` と `WHEN` にも分岐マークを付けられます。`structure_scope = { enable = true, char = "┆", show_branches = true }` で設定できます。外側の複数ブロックを同時に強調するわけではありません。

- Winbar は Division → Section → Paragraph → IF → EVALUATE → WHEN などの構造をパンくずとして表示します。狭いウィンドウでは内側を優先して左側を省略します。`:lua require("cobol.ast").show_breadcrumb_float()` で全体を浮動表示できます。
- Winbar 右側はカーソルを含む**解析済み・対応付け済み**ブロックの終了キーワードを内側から順に示します。`:CobolStructure` はこの情報を**通知**で表示し、`:lua require("cobol.ast").show_waiting_closures_float()` は別途浮動ウィンドウを開きます。終端のないブロックは対応付けできないため、欠落した `END-*` の検出には使えません。構文エラーの確認には `:CobolLint` を使ってください。
- 対応する開始・終了キーワードで `%` を押すと双方向に移動します。`vaf` / `vif` は IF の全体 / 内側、`vae` / `vie` は EVALUATE、`vap` / `vip` は PERFORM の範囲を選択します。演算子との組み合わせも可能です。
- 対応構造には `IF`、`EVALUATE`、`PERFORM`、`SEARCH`、`READ`、`WRITE`、`REWRITE`、`DELETE`、`START`、`STRING`、`UNSTRING` のほか、`XML PARSE`、`JSON PARSE`、`EXEC SQL`、`CLASS-ID`、`METHOD-ID`、`FACTORY`、`OBJECT` などが含まれます。文法にはコーパステストが同梱されています。
- Aerial 用バックエンドは Division、Section、Paragraph、FD/SD、01 レコードに加え、解析できた制御構造や SQL 文などを階層表示できます。Aerial を使わなくても他の編集・移動機能は利用できます。

本プラグインの折りたたみ式は Division、Section、Paragraph、データ項目を対象とします。**IF や EVALUATE の折りたたみそのものは生成しません**。別の折りたたみ提供元が制御ブロックの折りたたみを生成した場合、Tree-sitter を使って条件などを含む折りたたみ見出しを表示できます。`folding.foldtext` は `"auto"`（既定、nvim-ufo が管理する場合は譲る）、`"plugin"`（常に本プラグインを使用）、`"off"`（設定しない）を選べます。

## 補完、整形、サイズの概算

blink.cmp をインストールすると、`cobol`、`cbl`、`cob` バッファーに COBOL の補完ソースを登録します。予約語、構文スニペット、現在のファイルのデータ名・段落名、参照された Copybook の名前などを候補として提示します。COBOL LSP は必要ありません。

`:CobolFormatCase` は認識できる予約語を大文字にします。**範囲なしではバッファー全体**を処理し、Visual 選択や行範囲を指定した場合はその範囲だけを処理します。文字列、コメント、ユーザー定義名は維持します。完全なソース整形ではありません。

`<leader>cr` / `:CobolCalcRecord` は、DISPLAY、COMP/BINARY、COMP-3/PACKED-DECIMAL、基本項目の `OCCURS`、`REDEFINES` などについてサイズとオフセットを概算します。**グループ項目の OCCURS は子項目の合計を繰り返し回数倍せず、より大きい REDEFINES の重ね合わせも合計サイズを増やしません。** 実際の ABI・ファイル長は対象環境のコンパイラーで検証してください。ステータスラインへの組み込みには `require("cobol.statusline").component()` または `.format()` を利用できます。

## GnuCOBOL の診断とプロジェクト設定

診断は `cobc -fsyntax-only` を非同期で実行します。保存後、編集から 600 ms 経過後、Insert モードを抜けた後に実行でき、未保存の内容は可能な場合は標準入力から渡します。Copybook のエラーは開いている Copybook と参照元の `COPY` 行にも関連付けられます。自動診断は `:CobolDiagnosticsToggle` で切り替えられます。

現在のファイルから上方向に `.cobol.json`、Makefile、Git ルートを探してプロジェクトを判定します。必要ならプロジェクトルートに `.cobol.json` を作成します：

```json
{
  "source_format": "fixed",
  "dialect": "default",
  "compiler": "cobc",
  "copybook_paths": ["copy", "cpy"],
  "warnings": ["all", "no-obsolete"],
  "compiler_args": [],
  "commands": {
    "build": ["make", "build"],
    "run": ["make", "run"],
    "test": ["make", "test"]
  }
}
```

Copybook の相対パスはプロジェクトルートから解決されます。`source_format` は `fixed`、`free`、`auto` に対応します。ファイルがなければプラグイン側の設定を使用し、不正な JSON またはフィールドは警告して安全な既定値へ戻します。`commands` はシェルを通さず引数配列として実行します。未指定なら Makefile の `build`/`all`、`run`、`test`/`check` ターゲットを探し、単一ファイルには `cobc` を使用します。複数ファイルのプロジェクトには独自のビルドルールを用意してください。コマンド実行前に現在のファイルを保存してください。ビルドルールはあるのに `run` がなければ、実行ファイルを推測せずエラーにします。

グローバル設定では `source_format`、`project_root`、`copybook_paths`、`cobc_command`、`diagnostics`、`completion.enable`、`structure_scope`、`folding.foldtext` などを `opts` で変更できます。設定の詳細は[中国語の設定一覧](README.zh-CN.md#全局插件配置)と `:help cobol-configuration` を参照してください。ソースには `enabled`、`overflow_col`、`smart_comments` も宣言されていますが、現状ではそれぞれの動作を制御していないため、設定スイッチとして使用しないでください。

## コマンド一覧

| コマンド | 用途 |
| --- | --- |
| `:CobolGuideToggle` / `:CobolGuideEnable` / `:CobolGuideDisable` | ガイド、Winbar、診断のアタッチを切り替える（既存マッピングは残る） |
| `:CobolToggleComment` | 検出したソース形式に合わせてコメントを切り替える。行範囲も指定可能 |
| `:CobolGotoDef` / `:CobolGotoCopybook` / `:CobolPreview` | 定義へ移動、Copybook を開く、プレビューを表示 |
| `:CobolCalcRecord` | レコードのレイアウトを概算 |
| `:CobolStructure` | 対応付け済みブロックの終了キーワードを通知で表示（パーサーが必要） |
| `:CobolFormatCase` | 範囲なしならバッファー全体、行範囲指定時はその範囲の予約語を大文字化 |
| `:CobolLint` / `:CobolQuickfix` / `:CobolDiagnosticsToggle` | 構文チェック、Quickfix、自動診断の切り替え |
| `:CobolBuild` / `:CobolRun` / `:CobolTest` | プロジェクトのビルド、実行、テスト |

## 練習用リポジトリ

[iamcheyan/cobol](https://github.com/iamcheyan/cobol) には 32 の番号付きレッスンがあります。プラグインの利用に必須ではありません。

```bash
git clone https://github.com/iamcheyan/cobol.git ~/cobol-practice
cd ~/cobol-practice
make course-check
nvim lessons/01_hello-cobol/lesson.cob
```

各レッスンは `lessons/NN_*/` 以下にあり、`README.md`、`exercise.md`、`answer.md` と `lesson.cob` が基本です。Copybook などの補助ファイルがあるレッスンもあります。後半の SQL レッスンには別途 `make course-check-sql` が用意されています。

## 困ったとき・開発

- ガイドやキーがない場合は `:set filetype?` と `:verbose nmap gd` を確認します。
- 構造表示がない場合は C コンパイラーと COBOL パーサーを確認します。アウトラインには Aerial などを別途インストールします。
- 診断がない場合は `:echo executable('cobc')` と `cobc_command` を確認します。
- Copybook が見つからない場合は `copybook_paths` とプロジェクトルートを確認します。
- 記録長が違う場合は推定値を実際の ABI と取り違えず、対象コンパイラーで検証します。

リポジトリのルートで `./scripts/test.sh` を実行できます。Aerial がなければ Aerial 専用テストはスキップされます。ライセンスは [MIT](LICENSE) です。
