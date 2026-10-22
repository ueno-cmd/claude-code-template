#!/bin/bash
# guard-dangerous.test.sh
# guard-dangerous.sh にダミーの JSON を流し、判定（deny / ask / pass）を確認するテスト
# 実行: bash .claude/hooks/tests/guard-dangerous.test.sh

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARD="$TEST_DIR/../guard-dangerous.sh"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT

# テスト用の本番パターン
cat > "$WORK/patterns.txt" <<'EOF'
# コメント行は無視される

db.prod-example.internal
EOF
export GUARD_PATTERNS_FILE="$WORK/patterns.txt"

PASSED=0
FAILED=0

# 判定を取り出す（出力なしなら pass）
decide() {
  local out
  out="$(printf '%s' "$1" | bash "$GUARD")"
  if [ -z "$out" ]; then
    echo "pass"
  else
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'
  fi
}

# Bash ツールの入力で判定を確認する（$1: 期待値, $2: コマンド）
check_bash() {
  local json actual
  json="$(jq -n --arg c "$2" '{tool_name: "Bash", tool_input: {command: $c}}')"
  actual="$(decide "$json")"
  report "$1" "$actual" "Bash: $2"
}

# MCP ツールの入力で判定を確認する（$1: 期待値, $2: ツール名, $3: SQL）
check_mcp() {
  local json actual
  json="$(jq -n --arg t "$2" --arg s "$3" '{tool_name: $t, tool_input: {sql: $s}}')"
  actual="$(decide "$json")"
  report "$1" "$actual" "MCP($2): $3"
}

report() {
  if [ "$1" = "$2" ]; then
    PASSED=$((PASSED + 1))
    echo "  ✅ $3 → $2"
  else
    FAILED=$((FAILED + 1))
    echo "  ❌ $3 → $2（期待値: $1）"
  fi
}

echo "■ 広範囲の再帰削除"
check_bash deny 'rm -rf /'
check_bash deny 'rm -rf *'
check_bash deny 'rm -rf ~/'
check_bash deny 'rm -fr ../'
check_bash deny 'sudo rm -r --verbose /'
check_bash deny 'cd /tmp && rm -rf .'
check_bash deny 'rm -rf "$HOME"'
check_bash pass 'rm -f a.txt'
check_bash pass 'rm -rf ./build'
check_bash pass 'rm -rf node_modules dist'
check_bash pass 'rm *.log'

echo "■ git push の強制上書き"
check_bash deny 'git push -f'
check_bash deny 'git push --force origin main'
check_bash deny 'git push -uf origin main'
check_bash deny 'git push origin +main'
check_bash pass 'git push --force-with-lease origin main'
check_bash pass 'git push -u origin main'
check_bash pass 'grep -f patterns.txt file'
check_bash pass 'git commit -m "fix: --force オプションの説明を修正"'

echo "■ 本番DB"
check_bash deny 'psql -h db.prod-example.internal -c "DROP TABLE users"'
check_bash deny 'psql "$PROD_DATABASE_URL" -c "TRUNCATE users"'
check_bash deny 'RAILS_ENV=production rails db:drop'
check_bash deny 'npx prisma migrate reset --env production'
check_bash ask 'echo "DROP TABLE x"'
check_bash ask 'psql -c "TRUNCATE TABLE logs"'
check_bash ask 'psql -c "DELETE FROM users"'
check_bash ask 'npx supabase db reset'
check_bash ask 'psql -h db.prod-example.internal -c "select 1"'
check_bash ask 'mysql -h prod-db -e "select 1"'
check_bash pass 'psql -c "DELETE FROM users WHERE id = 1"'
check_bash pass 'NODE_ENV=production npm run build'
check_bash pass 'vite build --mode production'
check_bash pass 'truncate -s 0 app.log'
check_bash pass 'ls -la'

echo "■ MCP 経由のDB操作"
check_mcp deny 'mcp__postgres__query' 'DROP TABLE users -- prod'
check_mcp deny 'mcp__supabase__execute_sql' 'TRUNCATE orders; -- db.prod-example.internal'
check_mcp ask 'mcp__postgres__query' 'DELETE FROM sessions'
check_mcp ask 'mcp__supabase__execute_sql' 'select * from users -- production'
check_mcp pass 'mcp__postgres__query' 'select * from products'
check_mcp pass 'mcp__notion__search' 'production release notes'

echo "■ 秘密情報を含むコミット"
REPO="$WORK/repo"
git init -q "$REPO"
# テストファイル自体が検知されないよう、キーは分割して組み立てる
FAKE_KEY="AKIA""ABCDEFGHIJKLMNOP"
printf 'const key = "%s";\n' "$FAKE_KEY" > "$REPO/config.js"
printf 'API_KEY=%s\n' "$FAKE_KEY" > "$REPO/.env.example"
printf 'hello\n' > "$REPO/readme.txt"
export CLAUDE_PROJECT_DIR="$REPO"

git -C "$REPO" add readme.txt .env.example
check_bash pass 'git commit -m "add readme"'
check_bash deny 'git add . && git commit -m "wip"'
git -C "$REPO" add config.js
check_bash deny 'git commit -m "add config"'
git -C "$REPO" reset -q config.js
check_bash pass 'git commit -m "readme only"'
check_bash deny 'git commit -am "commit all"'

echo ""
echo "結果: ✅ ${PASSED} 件成功 / ❌ ${FAILED} 件失敗"
[ "$FAILED" -eq 0 ]
