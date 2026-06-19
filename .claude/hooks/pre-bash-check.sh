#!/bin/bash
# pre-bash-check.sh
# 危険なBashコマンドを事前にブロックするフック

COMMAND="$BASH_COMMAND"

# -----------------------------------------------
# ① rm -rf 系ワイルドカード・広範囲削除をブロック
# 対象: rm -rf * / ~/ ../ などの危険パターン
# -----------------------------------------------
if echo "$COMMAND" | grep -qE "rm\s+-[a-zA-Z]*rf?\s+([/*~]|\.\./)"; then
  echo "🚫 [HOOK] 危険な削除コマンドを検知してブロックしました。"
  echo "   コマンド: $COMMAND"
  echo "   対象を明示的に指定して再度お試しください。"
  exit 2
fi

# -----------------------------------------------
# ② git push --force 系をブロック
# 対象: --force / -f（--force-with-lease は通す）
# -----------------------------------------------
if echo "$COMMAND" | grep -qE "git\s+push\s+.*--force(?!-with-lease)|-f\b" ; then
  echo "🚫 [HOOK] git push --force をブロックしました。"
  echo "   コマンド: $COMMAND"
  echo "   履歴の強制上書きは禁止されています。"
  echo "   安全に行う場合は --force-with-lease を使用してください。"
  exit 2
fi

# 問題なければ通過
exit 0