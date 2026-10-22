# CLAUDE.md

このファイルは本プロジェクトにおける AI の行動指針の入口です。最上位命令として常に遵守すること。

## プロジェクト概要

Webアプリ・Webサイト（LP）・機械学習コンペで共通に使う開発テンプレート。
プロジェクト固有の要件は `docs/idea/initial-requirements.md` に書き、`/starter` で `docs/steering/` を生成して使う。

## ルール（`.claude/rules/` から自動で読み込まれる）

| ファイル | 内容 |
|---------|------|
| `communication.md` | 日本語での応答・トーン |
| `workflow.md` | プランモードでの計画承認・進行ルール・標準ワークフロー・完了前チェック |
| `steering.md` | ステアリングファイルを読む順番と扱い |
| `deliverables.md` | 成果物の言語・記録の保存先 |
| `production-safety.md` | 本番環境・秘密情報の安全管理 |

**優先順位**：`CLAUDE.md`・`.claude/rules/` ＞ `docs/steering/`

## 使える仕組み

- **スキル**：`/starter`（新規）・`/realign`（既存プロジェクトの把握）・`/src-scan`（大規模な src の分析）
- **エージェント**：`src-scanner`（ディレクトリ分析）・`steering-checker`（ステアリングとの整合確認）
- **フック**：`guard-dangerous.sh` が危険なコマンドと本番DB操作を実行前に止める
