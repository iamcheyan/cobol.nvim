# cobol.nvim

Neovim で COBOL を編集するためのプラグインです。固定形式 COBOL と、初学者がコードを読み進めるためのワークフローを重視しています。

ソースの列構成を確認し、段落やデータ定義を探し、Copybook を開き、レコードのレイアウトを確認できます。編集中の構文エラーも確認できます。言語サーバーは必要ありません。

[English](README.md) · [简体中文](README.zh-CN.md)

![cobol.nvim の概要](assets/cobol.nvim-overview.png)

スクリーンショットには、Aerial の構造アウトライン、固定形式の列ガイド、COBOL の移動機能、エディター内の Copybook プレビューが表示されています。Aerial は Neovim のコード構造を検索できる Outline サイドバーを提供するプラグインです。

## 対象ユーザー

固定形式 COBOL を学び始めた方、`.cob`、`.cbl`、`.cobol` を保守する方、Copybook と Division、Section、Paragraph 構造を使うプロジェクトに適しています。

基本機能は Aerial なしで動作します。Aerial は Neovim のコード構造 Outline サイドバーを提供するオプションプラグインで、`cobol.nvim` はそのための COBOL backend を提供します。

## 主な機能

| 分野 | 機能 | 役立つ場面 |
| --- | --- | --- |
| 固定形式 | 7、8、12、73 列のガイド、範囲外の強調、列ジャンプ | COBOL の各ソース領域を確認しながら編集できる |
| 構造と移動 | Winbar のパンくず、折りたたみ、`gd`、`gf`、`K` | Division、段落、フィールド、Copybook をたどりやすい |
| データレイアウト | PIC とレコードサイズの推定、`OCCURS`、`REDEFINES` 対応 | レコードのメモリ上の構成を学べる |
| コード補完 | COBOL のキーワード、動詞、句、スニペット、データ名、段落、Copybook | 入力を減らし、COBOL の語彙とプログラム構造を学びやすくする |
| コンテキスト情報 | 形式、ソース領域、パンくず、現在の PIC、レコードサイズ | 移動中も重要な COBOL の情報を確認できる |
| 診断 | 非同期の `cobc -fsyntax-only` と Quickfix | エディターを止めずに構文エラーを確認できる |
| 編集補助 | コメント切り替え、スマート Tab、予約語の大文字化 | 固定形式 COBOL の反復作業を減らせる |
| オプションのアウトライン | Aerial（Neovim のコード構造サイドバー）用 COBOL backend | プログラム構造を検索できる |

## 必要条件

- Neovim 0.10 以降
- [blink.cmp](https://github.com/saghen/blink.cmp) は任意です。インストールすると内蔵の COBOL 補完ソースが有効になります。
- GnuCOBOL（`cobc`）は任意。コンパイラー診断を使う場合に必要です。
- Aerial は任意です。Neovim のコード構造 Outline サイドバーを使う場合にインストールします。

## インストール

[lazy.nvim](https://github.com/folke/lazy.nvim) の設定例です。

```lua
{
  "iamcheyan/cobol.nvim",
  ft = { "cobol", "cbl", "cob" },
  opts = {},
}
```

Aerial のコード構造サイドバーを使う場合は、Aerial と COBOL backend を有効にします。

```lua
{
  "stevearc/aerial.nvim",
  optional = true,
  opts = function(_, opts)
    opts.backends = vim.tbl_deep_extend("force", opts.backends or {}, {
      cobol = { "cobol" },
    })
  end,
}
```

このプラグインは `cobc` を自動インストールしません。GnuCOBOL は別途インストールしてください。

## 設定

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
    folding = { enable = true },
    diagnostics = { enable = true, debounce_ms = 600 },
  },
}
```

`project_root` と `copybook_paths` は Copybook の移動と診断で使われます。`source_format` には `auto`、`fixed`、`free` を指定できます。ルートを指定しない場合は現在のファイルのディレクトリが使われます。

## 最初の使い方

1. COBOL ソースを開き、列ガイドを確認します。固定形式では 7 列目が指示領域、8–11 列が Area A、12–72 列が Area B、73 列目以降が識別領域です。
2. 段落名やデータ名で `gd`、`COPY` 文で `gf`、プレビューには `K` を使います。
3. オプションの Aerial Outline サイドバーを使う場合は `<leader>cs` で構造アウトラインを開きます。
4. 01 レコードまたはフィールド上で `<leader>cr` を押し、推定レイアウトを確認します。
5. 保存するか、`<leader>cl` で GnuCOBOL の構文チェックを実行します。
6. `za`、`zc`、`zo` で現在の構造を折りたたみます。

## 固定形式、移動、折りたたみ

`<leader>uc` または `:CobolGuideToggle` で列ガイドを切り替えられます。72 列を超えた文字は、多くのコンパイラーで無視されるため強調表示されます。

| キー | 用途 |
| --- | --- |
| `g7` / `g8` / `g12` / `g73` | 指示列、Area A、Area B、識別領域へ移動 |
| `gd` / `:CobolGotoDef` | 段落、データ定義、Copybook へ移動 |
| `gf` / `:CobolGotoCopybook` | Copybook を開く |
| `K` / `:CobolPreview` | 段落または Copybook をプレビュー |
| `<C-o>` | ジャンプリストで戻る |
| `<leader>cs` | Aerial Outline サイドバーを切り替える |
| `za` / `zc` / `zo` | 折りたたみを切り替え、閉じる、開く |

## コード補完

`blink.cmp` をインストールすると、`cobol`、`cbl`、`cob` のバッファーで COBOL 補完ソースが自動的に登録されます。COBOL 言語サーバーは必要ありません。

一般的な COBOL の動詞と句、`IF ... END-IF` や `PERFORM ... END-PERFORM` のような展開可能なスニペット、現在のファイルで定義されたデータ名、`COPY` で参照された Copybook のシンボルを候補に表示します。大文字と小文字は区別せず、`PER`、`WS-`、`COPY` などの接頭辞を入力すると候補を絞り込めます。

`blink.cmp` は任意の編集補助機能です。インストールしなくても、列ガイド、移動、計算、折りたたみ、整形、診断は利用できます。

Division、Section、Paragraph、データレコードをネイティブに折りたためます。Insert モードの `<Tab>` は Area A または Area B に合わせて入力位置を移動します。`<leader>c*` と `:CobolToggleComment` は 7 列目のコメントを追加・削除します。

## フォーマットと PIC 計算

`:CobolFormatCase` は現在行、Visual 選択、バッファ全体を対象に、認識した予約語だけを整形します。文字列、コメント、ユーザー定義名は保持されます。

`<leader>cr` または `:CobolCalcRecord` では、`DISPLAY`、`COMP`/`BINARY`、`COMP-3`/`PACKED-DECIMAL`、`OCCURS`、`REDEFINES` のサイズを推定します。値は学習やレビュー向けの推定値であり、実際の ABI と記憶域配置はコンパイラーで確認してください。

## 診断

次のコマンドを非同期で実行できます。

```text
cobc -fsyntax-only ...
```

保存時、変更後のデバウンス完了時、Insert モードを抜けた時にチェックします。`<leader>cl` / `:CobolLint` で即時実行し、`<leader>cq` / `:CobolQuickfix` で Quickfix を開きます。自動診断は `:CobolDiagnosticsToggle` で切り替えます。

`cobc` がない場合もプラグインは停止しません。GnuCOBOL をインストールするか、`cobc_command` を正しい実行ファイルに変更してください。

## コマンド

| コマンド | 用途 |
| --- | --- |
| `:CobolGuideToggle` / `:CobolGuideEnable` / `:CobolGuideDisable` | ガイドと Winbar の切り替え |
| `:CobolGotoDef` / `:CobolGotoCopybook` / `:CobolPreview` | 定義移動、Copybook、プレビュー |
| `:CobolCalcRecord` | レコードレイアウトの推定 |
| `:CobolFormatCase` | 予約語の整形 |
| `:CobolLint` / `:CobolQuickfix` | 診断と Quickfix |
| `:CobolDiagnosticsToggle` | 自動診断の切り替え |
| `:CobolToggleComment` | 固定形式コメントの切り替え |

## 練習用リポジトリ

[iamcheyan/cobol](https://github.com/iamcheyan/cobol) は、小さく実行可能な COBOL ワークショップです。プラグインに必須ではありませんが、ここで紹介した機能を練習できます。

```bash
git clone https://github.com/iamcheyan/cobol.git ~/cobol-practice
cd ~/cobol-practice
make check
nvim INPUTCSV.COB
```

固定形式、Copybook、PIC と記憶域、`REDEFINES`、`OCCURS`、`SEARCH ALL`、コントロールブレイク集計を学べます。`docs/01` から `docs/07` を順番に読み、最後のレッスンでプラグインの移動、計算、折りたたみ、フォーマット、診断を試してください。

## 困ったときは

- **列ガイドがない：** `:set filetype?` で `cobol` になっているか確認してください。
- **アウトラインがない：** サイドバーはオプションの Aerial Neovim プラグインが提供します。インストールして上記の設定を追加してください。
- **診断がない：** `:echo executable('cobc')` を実行し、GnuCOBOL と `cobc_command` を確認してください。
- **Copybook が見つからない：** `project_root` と `copybook_paths` を設定してください。
- **サイズが違う：** 計算結果は推定値です。コンパイラーとプラットフォーム資料で確認してください。

## 開発とライセンス

```bash
./scripts/test.sh
```

Aerial がない場合、Aerial 専用テストはスキップされます。その他のコアテストには Aerial は必要ありません。MIT。詳細は [LICENSE](LICENSE) を参照してください。

完了済みおよび今後の拡張項目は [docs/ENHANCEMENTS.md](docs/ENHANCEMENTS.md) にまとめています。
