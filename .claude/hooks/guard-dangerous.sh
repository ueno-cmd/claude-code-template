#!/bin/bash
# guard-dangerous.sh
# 危険な操作を実行前に止める PreToolUse フック（対象: Bash / mcp__.*）
# stdin で受け取った JSON を検査し、ブロック（deny）か確認（ask）を JSON で返す
#
#   ブロック : 広範囲の rm -r / git の force push / 秘密情報を含むコミット / 本番 × 破壊的DB操作
#   確認     : 破壊的DB操作のみ / 本番DBへのアクセスのみ
#
# 本番DBのホスト名などは protected-patterns.txt に1行1つずつ書く（空でも動く）

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
PATTERNS_FILE="${GUARD_PATTERNS_FILE:-$HOOK_DIR/protected-patterns.txt}"  # テスト時は環境変数で差し替え可能

# -----------------------------------------------
# 検知パターン
# -----------------------------------------------

# 破壊的なDB操作（大文字小文字は区別しない）
DESTRUCTIVE_RE='drop[[:space:]]+(database|table|schema)|truncate[[:space:]]+(table[[:space:]]+)?[a-z_"`]|migrate[[:space:]:]+reset|db:(drop|reset|schema:load)|db[[:space:]]+reset|--force-reset|(^|[^a-z])dropdb([^a-z]|$)|flushall|flushdb'

# 本番を示す汎用キーワード（DB操作の文脈でのみ使う。ビルド時の NODE_ENV=production などを誤検知しないため）
PROD_RE='(^|[^a-z])prod(uction)?([^a-z]|$)'

# DB操作の文脈とみなすコマンド（Bash）
DB_CLI_RE='(^|[^a-z])(psql|mysql|mariadb|mongosh|mongo|redis-cli|sqlite3|sqlcmd|pg_dump|pg_restore|prisma|supabase|drizzle-kit|knex|sequelize|typeorm|dbmate|flyway|liquibase)([^a-z]|$)|rails[[:space:]]+(db|console|dbconsole)|rake[[:space:]]+db|manage\.py'

# DB操作の文脈とみなす MCP ツール名
DB_MCP_RE='sql|postgres|mysql|supabase|mongo|redis|neon|planetscale|turso|database|_db|db_'

# 秘密情報らしき文字列（APIキー・トークン・秘密鍵）
SECRET_RE='(sk-|sk-ant-|AKIA|ghp_|github_pat_|xoxb-|AIza)[A-Za-z0-9_-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'

# -----------------------------------------------
# ヘルパー
# -----------------------------------------------

# 判定結果を JSON で返して終了する（$1: deny / ask, $2: 理由）
respond() {
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

# コマンドを ; & | 改行 で区切り、1行1セグメントで出力する
segments() {
  printf '%s\n' "$1" | tr ';&|' '\n\n\n'
}

# 引用符を外したトークンを返す
unquote() {
  local t="${1//\"/}"
  printf '%s' "${t//\'/}"
}

# 広範囲を対象にした再帰削除か（rm -r / -rf / --recursive と /, *, ~, .., . などの組み合わせ）
is_dangerous_rm() {
  local seg tok recursive danger
  while IFS= read -r seg; do
    set -f  # トークン分割時に * を展開させない
    set -- $seg
    set +f
    # sudo・環境変数の代入・command を読み飛ばす
    while [ $# -gt 0 ]; do
      case "$1" in
        sudo|command|exec|time|\(|\{|*=*) shift ;;
        *) break ;;
      esac
    done
    [ "$(basename -- "${1:-x}")" = "rm" ] || continue
    shift
    recursive=0
    danger=0
    for tok in "$@"; do
      tok="$(unquote "$tok")"
      case "$tok" in
        --recursive) recursive=1 ;;
        --*) ;;
        -*[rR]*) recursive=1 ;;
        /|/\*|\*|.|./|./\*|..|../|../\*|\~|\~/|\~/\*|'$HOME'|'$HOME/'|'$HOME/*') danger=1 ;;
      esac
    done
    [ "$recursive" -eq 1 ] && [ "$danger" -eq 1 ] && return 0
  done < <(segments "$1")
  return 1
}

# git の指定サブコマンドを見つけたら "__found__" を、続けてそれ以降のトークンを1行1つで出力する
# （$1: コマンド, $2: サブコマンド）
git_args() {
  local seg tok in_git found
  local sub="$2"  # 下の set -- で位置パラメータが上書きされるため退避する
  while IFS= read -r seg; do
    set -f
    set -- $seg
    set +f
    in_git=0
    found=0
    for tok in "$@"; do
      if [ "$found" -eq 1 ]; then
        printf '%s\n' "$tok"
      elif [ "$in_git" -eq 1 ] && [ "$tok" = "$sub" ]; then
        found=1
        echo "__found__"
      elif [ "$(basename -- "$tok")" = "git" ]; then
        in_git=1
      fi
    done
  done < <(segments "$1")
}

# git push の強制上書きか（--force / -f / +refspec。--force-with-lease は許可）
is_force_push() {
  local tok
  while IFS= read -r tok; do
    case "$tok" in
      --force-with-lease*|--force-if-includes) ;;
      --force) return 0 ;;
      --*) ;;
      -*f*) return 0 ;;
      +*) return 0 ;;
    esac
  done < <(git_args "$1" push)
  return 1
}

# git commit か（成功時、-a / --all 付きなら "all" を出力する）
is_git_commit() {
  local tok committing=1
  while IFS= read -r tok; do
    case "$tok" in
      __found__) committing=0 ;;
      --all) echo "all" ;;
      --*) ;;
      -*a*) echo "all" ;;
    esac
  done < <(git_args "$1" commit)
  return "$committing"
}

# コミット予定の変更に秘密情報らしき文字列があるか
# （$1: "all" なら未ステージの変更と未追跡ファイルも含める。git add と同時実行される場合に対応）
has_secret_in_commit() {
  local diff
  diff="$(git diff --cached -- . ':(exclude)*.example' 2>/dev/null | grep -E '^\+')"
  if [ "$1" = "all" ]; then
    diff="$diff
$(git diff -- . ':(exclude)*.example' 2>/dev/null | grep -E '^\+')
$(git ls-files --others --exclude-standard -z -- . ':(exclude)*.example' 2>/dev/null | xargs -0 cat 2>/dev/null)"
  fi
  printf '%s\n' "$diff" | grep -qE "$SECRET_RE"
}

# WHERE 句のない DELETE 文があるか
has_unbounded_delete() {
  printf '%s' "$1" | grep -ioE 'delete[[:space:]]+from[^;"]*' | grep -qviE 'where'
}

# protected-patterns.txt のいずれかに一致するか（コメント行・空行は無視、固定文字列として比較）
matches_protected() {
  local pats
  [ -f "$PATTERNS_FILE" ] || return 1
  pats="$(grep -vE '^[[:space:]]*(#|$)' "$PATTERNS_FILE" | sed 's/[[:space:]]*$//')"
  [ -n "$pats" ] || return 1
  printf '%s' "$1" | grep -qiF -f <(printf '%s\n' "$pats")
}

# -----------------------------------------------
# 入力の読み込み
# -----------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
  echo "🚫 [HOOK] jq が見つからないため安全チェックを実行できません。jq をインストールしてください。" >&2
  exit 2
fi

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)"

if [ "$TOOL_NAME" = "Bash" ]; then
  TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)"
else
  # MCP ツールは引数名がツールごとに違う（sql / query など）ため、tool_input 全体を検査する
  TARGET="$(printf '%s' "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)"
fi

[ -n "$TARGET" ] || exit 0

# -----------------------------------------------
# ① Bash 固有のチェック
# -----------------------------------------------

if [ "$TOOL_NAME" = "Bash" ]; then
  if is_dangerous_rm "$TARGET"; then
    respond deny "🚫 広範囲を対象にした再帰削除をブロックしました。削除対象を明示的に指定してください。"
  fi

  if is_force_push "$TARGET"; then
    respond deny "🚫 git push の強制上書きをブロックしました。必要な場合は --force-with-lease を使い、ユーザーに確認してください。"
  fi

  if COMMIT_MODE="$(is_git_commit "$TARGET")"; then
    git_args "$TARGET" add | grep -q '^__found__$' && COMMIT_MODE="all"
    [ -n "$CLAUDE_PROJECT_DIR" ] && cd "$CLAUDE_PROJECT_DIR" 2>/dev/null
    if has_secret_in_commit "$COMMIT_MODE"; then
      respond deny "🚫 コミット予定の変更にAPIキーらしき文字列があります。秘密情報を取り除いてからコミットしてください。"
    fi
  fi
fi

# -----------------------------------------------
# ② 本番DBのチェック（Bash / MCP 共通）
# -----------------------------------------------

DESTRUCTIVE=0
PROD=0

if printf '%s' "$TARGET" | grep -qiE "$DESTRUCTIVE_RE" || has_unbounded_delete "$TARGET"; then
  DESTRUCTIVE=1
fi

if matches_protected "$TARGET"; then
  PROD=1
elif printf '%s' "$TARGET" | grep -qiE "$PROD_RE"; then
  if [ "$TOOL_NAME" = "Bash" ]; then
    printf '%s' "$TARGET" | grep -qiE "$DB_CLI_RE" && PROD=1
  else
    printf '%s' "$TOOL_NAME" | grep -qiE "$DB_MCP_RE" && PROD=1
  fi
fi

if [ "$DESTRUCTIVE" -eq 1 ] && [ "$PROD" -eq 1 ]; then
  respond deny "🚫 本番環境への破壊的なDB操作をブロックしました。本番での実行はユーザー自身が行ってください。"
fi

if [ "$DESTRUCTIVE" -eq 1 ]; then
  respond ask "⚠️ 破壊的なDB操作（DROP / TRUNCATE / WHERE句なしDELETE / reset など）を検知しました。接続先と影響範囲を確認してください。"
fi

if [ "$PROD" -eq 1 ]; then
  respond ask "⚠️ 本番環境のDBへのアクセスを検知しました。接続先が正しいか確認してください。"
fi

exit 0
