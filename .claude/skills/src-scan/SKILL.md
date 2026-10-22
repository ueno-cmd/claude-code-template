---
name: src-scan
description: /realign で「白旗」になった大規模な src/ をディレクトリごとに並列分析し、docs/realign-summary.md の src セクションを更新する
argument-hint: "[スキャン対象ディレクトリ（省略時は src）]"
disable-model-invocation: true
---

# /src-scan

`docs/realign-summary.md` の src セクションを本格分析で上書きします。
`/realign` 完了後に実行してください。

スキャン対象：`$ARGUMENTS`（空欄の場合は `src/`）

---

## 実行手順

### Phase 1: 前提確認

```bash
cat docs/realign-summary.md 2>/dev/null
ls ${ARGUMENTS:-src}/ 2>/dev/null
```

`docs/realign-summary.md` が存在しない場合は `/realign` を先に実行するよう伝えて終了してください。

---

### Phase 2: トップディレクトリ一覧を取得

```bash
ls -1 ${ARGUMENTS:-src}/
```

取得したトップディレクトリのリストを確認し、`src-scanner` エージェントへの割り当てを決めてください。

---

### Phase 3: ディレクトリ別並列分析

Phase 2 で取得したトップディレクトリごとに、**`src-scanner` エージェントを並列で**起動してください（1回のメッセージでまとめて起動する）。

各エージェントには担当ディレクトリのパス（例: `src/components`）だけを渡します。
分析手順と返却する JSON の形式は `.claude/agents/src-scanner.md` に定義されています。

---

### Phase 4: 結果を統合・分析

全タスクの JSON を受け取ったら以下を判定してください。

- **命名規則の統一度**: 全体を通してどのスタイルが主流か
- **構成パターン**: Feature-based / Atomic Design / レイヤード / 混在
- **主要な問題点**: バイブコーディング起因と思われる不整合
- **ステアリングファイルに書くべきルール**: 今後守るべき規約の候補

---

### Phase 5: サマリ更新

`docs/realign-summary.md` の `## src/` セクションを以下のフォーマットで**上書き**してください。
他のセクションは変更しないでください。

```markdown
## src/

> /src-scan 完了（{YYYY-MM-DD}）

### 構成

| ディレクトリ | ファイル数 | 役割（推定） |
|-------------|-----------|-------------|
| components/ | 42        | UIコンポーネント群 |
| ...         | ...       | ... |

### 命名規則

- コンポーネント: PascalCase（統一）
- ユーティリティ: camelCase（概ね統一、一部 snake_case が混在）

### 構成パターン

{検出したパターンと根拠}

### 検出された問題

- {問題1}
- {問題2}

### ステアリングファイル候補ルール

- {今後守るべきルール1}
- {今後守るべきルール2}
```

更新後、ファイル末尾の「次のアクション」を以下に差し替えてください。

```markdown
## 次のアクション

→ `/src-scan` 完了。このサマリを確認後、ステアリングファイルの書き込み先を指定してください。
```

---

## 注意事項

- `docs/realign-summary.md` の `## src/` セクション**のみ**を変更する
- ステアリングファイルはまだ生成しない
- 更新前にプランモードで「作業計画（上書き対象セクションの確認）」を提示し、ユーザーの承認を得てから書き込む