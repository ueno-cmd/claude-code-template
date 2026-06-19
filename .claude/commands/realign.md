# /realign

既存プロジェクトをスキャンし、`docs/realign-summary.md` にサマリを書き出します。
ステアリングファイルは**書きません**。サマリの確認と `/src-scan` の完了後に別途生成します。

---

## 実行手順

### Phase 1: 並列スキャン

以下を**並列で**実行してください。

**[タスク A] ディレクトリ構造**
```bash
find . -maxdepth 3 -type d \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/.next/*' \
  -not -path '*/dist/*' \
  -not -path '*/__pycache__/*'
```

**[タスク B] 技術スタック検出**
```bash
cat package.json 2>/dev/null
cat pyproject.toml 2>/dev/null
cat requirements.txt 2>/dev/null
cat Cargo.toml 2>/dev/null
cat go.mod 2>/dev/null
cat composer.json 2>/dev/null
```

**[タスク C] Git 概況**
```bash
git log --oneline -30 2>/dev/null
git branch -a 2>/dev/null
git status --short 2>/dev/null
```

**[タスク D] 既存ドキュメント**
```bash
cat README.md 2>/dev/null
cat CLAUDE.md 2>/dev/null
ls docs/ 2>/dev/null
```

**[タスク E] src 規模計測（これだけ）**
```bash
ls src/ 2>/dev/null
find src -type f 2>/dev/null | wc -l
find src -type d 2>/dev/null | awk -F/ '{print NF}' | sort -n | tail -1
```

タスク E は規模計測のみです。ファイルの中身は読まないでください。

---

### Phase 2: src セクションの判断

タスク E の結果をもとに以下の基準で分岐してください。

**小規模（ファイル数 ≦ 80 かつ 深さ ≦ 3）の場合**
- `src/` の各トップディレクトリからファイルを 2〜3 件選んで冒頭 30 行を読む
- 命名規則・構成パターンを推定してサマリの src セクションに記載する

**大規模（上記を超える）の場合**
- サマリの src セクションに以下の 1 行だけ書いて終わりにする

```
⚠️ 自分一人では白旗です。要 /src-scan（ファイル数: {N}件 / 深さ: {D}階層 / トップディレクトリ: {一覧}）
```

それ以上 src を読もうとしないでください。

---

### Phase 3: サマリ書き出し

以下のフォーマットで `docs/realign-summary.md` を作成してください。
`docs/` ディレクトリが存在しない場合は作成してください。

```markdown
# リアラインメントサマリ

> 生成日時: {YYYY-MM-DD}
> コマンド: /realign
> ステータス: 暫定（src-scan 未完了）または 完了

---

## 技術スタック

{検出した言語・フレームワーク・主要ライブラリ}

## ディレクトリ構造（src 除く）

{find 結果から src 以外の構成を記述}

## src/

{小規模なら分析結果 / 大規模なら白旗1行}

## Git 概況

- 総コミット数（概算）: {N} 件
- 直近の動き: {git log 要約}
- 未マージブランチ: {あれば}

## 既存ドキュメント

{README / CLAUDE.md の有無と概要}

## 次のアクション

{src が白旗の場合}
→ `/src-scan` を実行してください。完了後にステアリングファイルを生成します。

{src が完了の場合}
→ このサマリを確認後、ステアリングファイルの書き込み先を指定してください。
```

---

## 注意事項

- `node_modules/` `.git/` `dist/` `.next/` `__pycache__/` は読まない
- ファイルの中身を読んでいい場所は技術スタック検出（タスク B）と、小規模 src のサンプル読み（Phase 2）のみ
- `docs/realign-summary.md` 以外のファイルは作成・変更しない
- サマリ生成前に「作業計画」を提示し、ユーザーの承認（y）を得てから書き出す