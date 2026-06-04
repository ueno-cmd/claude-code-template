---
allowed-tools: []
description: "初期要件を読み込んでステアリングファイルを自動生成する"
---

# スターター：ステアリングファイル生成

以下の手順でプロジェクトの要件を把握し、ステアリングファイルを生成してください。

## ステップ0：スキルの読み込み

以下のスキルを読み込んでください：
- `superpowers:brainstorming`
- `superpowers:writing-plans`
- `superpowers:executing-plans`

## ステップ1：ドキュメントの読み込み

まず、以下のファイルを読み込んでください。

1. `docs/idea/initial-requirements.md` — 初期要件・アイデアの概要

## ステップ2：内容の整理と矛盾点の確認

読み込んだ内容を元に、以下を整理してください。

- プロジェクトの目的・ゴール
- 技術的な制約や前提条件
- **矛盾点・曖昧な点があれば、ファイル生成前に必ず指摘・確認すること**

## ステップ3：ステアリングファイルの自動生成

読み込んだ内容を踏まえて、`docs/steering/` 以下に以下の3ファイルを生成してください。

- `docs/steering/requirements.md` — 整理された、正式な要件定義書
- `docs/steering/repo-structure.md` — ディレクトリ構成・ファイル責務
- `docs/steering/glossary.md` — 変数名・関数名・UI用語の定義
- `docs/steering/dev-guidelines.md` — コーディングルール・禁止事項

生成後、内容をユーザーに提示して確認を取ること。