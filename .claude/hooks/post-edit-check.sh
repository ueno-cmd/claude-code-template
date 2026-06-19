#!/bin/bash
# post-edit-check.sh
# ファイル編集後に自動で品質チェックを行うフック
# プロジェクト種別に応じてコメントを外して使用してください

# -----------------------------------------------
# フロントエンド向け（TypeScript / React 系）
# 必要なものだけコメントを外す
# -----------------------------------------------

# ① TypeScript 型チェック
# npm run typecheck 2>&1 || { echo "🚫 [HOOK] 型チェックに失敗しました。修正してください。"; exit 2; }

# ② ESLint
# npm run lint 2>&1 || { echo "🚫 [HOOK] Lint エラーがあります。修正してください。"; exit 2; }

# -----------------------------------------------
# バックエンド向け（Python / Node.js 系）
# 必要なものだけコメントを外す
# -----------------------------------------------

# ③ pytest（Python）
# pytest --tb=short 2>&1 || { echo "🚫 [HOOK] テストに失敗しました。修正してください。"; exit 2; }

# ④ Jest / Vitest（Node.js）
# npm test -- --passWithNoTests 2>&1 || { echo "🚫 [HOOK] テストに失敗しました。修正してください。"; exit 2; }

# -----------------------------------------------
# 全プロジェクト共通（常時有効）
# -----------------------------------------------

# ⑤ 秘密情報の誤コミット防止（APIキー・トークン検出）
if grep -rE "(sk-|AKIA|ghp_|xoxb-|AIza)[a-zA-Z0-9]{10,}" \
   --include="*.ts" --include="*.tsx" --include="*.js" \
   --include="*.py" --include="*.env" . 2>/dev/null | \
   grep -v ".env.example"; then
  echo "🚫 [HOOK] APIキーらしき文字列を検出しました。コミット前に確認してください。"
  exit 2
fi

exit 0