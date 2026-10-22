# claude-code-template

**Claude Code でAI駆動開発を行うためのプロジェクト・テンプレート（雛形）です。**

実際のアプリケーションコードは含まれていません。AIに開発作業を任せるための「行動指針・進行ルール・自動化の仕組み」を事前にセットアップした土台であり、Webアプリ・Webサイト（LP）・機械学習コンペなどの新しいプロジェクトを始めたり、既存プロジェクトの整理に使ったりします。

---

## 特徴

このテンプレートは、AIとの開発を安全かつ一貫させるための **3本の柱** で構成されています。

1. **ステアリング方式** — 要件メモから「指針ファイル群（`docs/steering/`）」を生成し、AIは常にそれに従って開発します。プロジェクトの方針がブレません。
2. **計画承認ルール** — AIはいきなりコードを書き始めず、プランモードで作業計画を提示して承認を得てから着手します。
3. **本番ガード** — 危険なコマンドや本番DBへの破壊的操作を、フックが実行前にブロック（または確認）します。

---

## 想定する技術スタック

新規開発時に想定しているスタックです（`docs/idea/initial-requirements.md` より）。

- **Vite + React + TypeScript**
- **CSS Modules またはインラインスタイル**（外部UIライブラリ不使用）
- **外部ライブラリ・CDN 不使用**
- **サーバー不要**（ブラウザだけで動く静的アプリ）
- **モバイル対応必須**（レスポンシブデザイン）／ IEサポート不要

> ※ これは想定であり、別のスタックで使うこともできます。

---

## ディレクトリ構成

```
claude-code-template/
├── CLAUDE.md                       # AIへの行動指針の入口（rules への案内）
├── README.md                       # このファイル
├── .gitignore                      # 個人用設定（CLAUDE.local.md 等）を除外
├── .claude/
│   ├── settings.json               # 権限（.env の読み取り禁止）とフックの登録
│   ├── rules/                      # AIが常に読み込むルール（CLAUDE.md から分割）
│   │   ├── communication.md        # 日本語・トーン
│   │   ├── workflow.md             # 計画承認・進行ルール・標準ワークフロー
│   │   ├── steering.md             # ステアリングファイルの読み方
│   │   ├── deliverables.md         # 成果物の言語・記録の保存先
│   │   └── production-safety.md    # 本番環境・秘密情報の安全管理
│   ├── skills/                     # スラッシュコマンドとして使えるスキル
│   │   ├── starter/SKILL.md        # 要件 → ステアリングファイル自動生成
│   │   ├── realign/SKILL.md        # 既存プロジェクトをスキャンして要約
│   │   └── src-scan/SKILL.md       # src/ を並列分析して要約を更新
│   ├── agents/                     # サブエージェント
│   │   ├── src-scanner.md          # ディレクトリ単位の読み取り専用分析
│   │   └── steering-checker.md     # 変更がステアリングに沿っているか確認
│   └── hooks/
│       ├── guard-dangerous.sh      # 危険なコマンド・本番DB操作を実行前に止める
│       ├── protected-patterns.txt  # 本番DBのホスト名などを記入（プロジェクトごと）
│       └── tests/
│           └── guard-dangerous.test.sh  # フックのテスト
└── docs/
    ├── idea/
    │   └── initial-requirements.md # 開発者が最初に書く要件メモ
    └── steering/                   # AIが自動生成する指針ファイル群
        ├── requirements.md         # 整理された正式な要件定義書
        ├── repo-structure.md       # ディレクトリ構成・ファイル責務
        ├── glossary.md             # 変数名・関数名・UI用語の定義
        └── dev-guidelines.md       # コーディングルール・禁止事項
```

---

## 使い方（クイックスタート）

用途に応じて、最初に実行するコマンドが変わります。

### 🟢 ゼロから新規開発する場合

1. `docs/idea/initial-requirements.md` の空欄（やりたいこと・機能など）を埋める
2. 本番DBを使うプロジェクトなら、`.claude/hooks/protected-patterns.txt` に本番のホスト名などを書く
3. `/starter` を実行する
4. AIが `docs/steering/` 配下に4つの指針ファイルを生成する
5. 内容を確認・承認したら、プランモードでの計画化を経て実装へ進む

### 🔵 既存プロジェクトに参入する場合

1. `/realign` を実行し、プロジェクト全体をスキャンして `docs/realign-summary.md` に要約を出力する
2. `src/` が大規模で「白旗」と判定されたら、続けて `/src-scan` を実行して精密分析する
3. 要約を確認後、ステアリングファイルの生成に進む

```
┌─ 新規で作る ─────────────→ /starter ──→ ステアリングファイル完成
│
└─ 既存に参入する ─→ /realign ──┬─ src 小規模 → そのまま要約完成
                                │
                                └─ src 大規模（白旗）→ /src-scan → 要約完成
```

---

## スキル（スラッシュコマンド）一覧

| コマンド | 使うとき | 入力（読む） | 出力（書く） |
|---------|---------|------------|------------|
| `/starter` | ゼロから新規開発を始めるとき | `docs/idea/initial-requirements.md` | `docs/steering/` の4ファイル |
| `/realign` | 既存プロジェクトの全体像を素早く掴みたいとき | プロジェクト全体（package.json・git・README 等） | `docs/realign-summary.md` |
| `/src-scan [dir]` | `/realign` で「src が大きすぎて白旗」になったとき | `src/`（または指定ディレクトリ）配下を `src-scanner` エージェントで並列精査 | `docs/realign-summary.md` の src セクションのみ |

> どれもファイルを書き込むため、AIが勝手に起動しないよう `disable-model-invocation: true` を設定しています。
> `/src-scan` は単体では使わず、必ず `/realign` の後に実行します。

---

## サブエージェント

| エージェント | 役割 | 使えるツール |
|------------|------|------------|
| `src-scanner` | 1ディレクトリを分析し JSON で返す（`/src-scan` から呼ばれる） | Read / Grep / Glob（読み取り専用） |
| `steering-checker` | 変更がステアリングファイル（スコープ・配置・用語・規約）に沿っているか確認する | Read / Grep / Glob / Bash（git の参照のみ） |

> バグの検出は Claude Code 組み込みの `/code-review` に任せ、`steering-checker` はステアリングとの整合だけを見ます。

---

## 本番ガード（フック）

`.claude/settings.json` で、`Bash` と MCP ツール（`mcp__.*`）の実行前に `guard-dangerous.sh` が動きます。

| 検知内容 | 判定 |
|---------|------|
| `rm -rf /`・`rm -rf *`・`rm -rf ~` など広範囲の再帰削除 | 🚫 ブロック |
| `git push --force` / `-f` / `+ブランチ`（`--force-with-lease` は通す） | 🚫 ブロック |
| `git commit` 時、コミット予定の変更にAPIキーらしき文字列がある | 🚫 ブロック |
| 破壊的なDB操作（DROP / TRUNCATE / WHERE句なしDELETE / `migrate reset` / `db:drop` など）× 本番 | 🚫 ブロック |
| 破壊的なDB操作のみ | ⚠️ 実行前に確認 |
| 本番DBへのアクセスのみ | ⚠️ 実行前に確認 |

「本番」かどうかは、次の2つで判定します。

- `.claude/hooks/protected-patterns.txt` に書いた文字列（1行1つ、固定文字列）
- DBコマンド（`psql`・`prisma` など）やDB系 MCP の中に出てくる `prod` / `production` というキーワード

フックは最後の砦です。本番の接続情報を開発環境に置かないことが基本です（`.claude/rules/production-safety.md`）。
また `.env`・`.env.local`・`.env.production`・`.env.*.local` は、`permissions.deny` で読み取りを禁止しています。

パターンを変更したら、次のコマンドでテストしてください（動作には `jq` が必要です）。

```bash
bash .claude/hooks/tests/guard-dangerous.test.sh
```

### プロジェクト固有のチェックを足したい場合

型チェック・Lint・テストなどはプロジェクトごとに違うので、テンプレートには入れていません。必要なら、そのプロジェクトの `.claude/settings.json` に PostToolUse フックを追加します。`if` でファイルパスを絞り込めます。

```json
"PostToolUse": [
  {
    "matcher": "Edit|Write",
    "hooks": [
      { "type": "command", "if": "Edit(src/**/*.ts)", "command": "npm run typecheck" }
    ]
  }
]
```

> `if` に書けるルールは1つだけです。条件を複数にしたい場合は、ハンドラーを分けて並べます。

---

## プラグインをプロジェクト単位で使う

superpowers や frontend-design は、全体（ユーザー設定）ではなく、必要なプロジェクトでだけ有効化する方針です。
そのプロジェクトの `.claude/settings.json` に、次のように追記します。

```json
{
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true
  }
}
```

> プラグイン本体が各自のマシンにインストールされている必要があります（`/plugin` で確認・インストール）。
> 有効にした場合は、`workflow.md` の該当フェーズでそれらのスキルを使えます。

---

## 開発ワークフローとルール

ワークフローの6つのフェーズとAIが守るルールは、`.claude/rules/` にまとまっています。詳しくは各ファイルを参照してください。

- 進行ルール・ワークフロー → [`.claude/rules/workflow.md`](.claude/rules/workflow.md)
- コミュニケーション → [`.claude/rules/communication.md`](.claude/rules/communication.md)
- 成果物 → [`.claude/rules/deliverables.md`](.claude/rules/deliverables.md)
- ステアリング → [`.claude/rules/steering.md`](.claude/rules/steering.md)
- 本番の安全管理 → [`.claude/rules/production-safety.md`](.claude/rules/production-safety.md)

個人だけの設定は `CLAUDE.local.md` や `.claude/settings.local.json` に書きます（どちらも `.gitignore` 済み）。
