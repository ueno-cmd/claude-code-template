// guard-env.test.js
// guard-env.js にダミーの JSON を流し、終了コード（2: ブロック / 0: 通過）を確認するテスト
// 実行: node .claude/hooks/tests/guard-env.test.js

const { spawnSync } = require("node:child_process");
const path = require("node:path");

const HOOK = path.join(__dirname, "..", "guard-env.js");

let passed = 0;
let failed = 0;

// フックを実行して判定を返す（exit 2: "block" / exit 0: "pass" / それ以外: クラッシュとしてエラー内容を返す）
function decide(input) {
    const result = spawnSync("node", [HOOK], { input, encoding: "utf8" });
    if (result.status === 2) return "block";
    if (result.status === 0) return "pass";
    return `error(status=${result.status}) ${result.error?.message || result.stderr}`;
}

function report(expected, actual, label) {
    if (expected === actual) {
        passed++;
    } else {
        failed++;
        console.log(`❌ ${label}（期待: ${expected} / 実際: ${actual}）`);
    }
}

// Bash ツールの入力で判定を確認する
function checkBash(expected, command) {
    const input = JSON.stringify({ tool_name: "Bash", tool_input: { command } });
    report(expected, decide(input), `Bash: ${command}`);
}

// --- ブロックされるもの ---
checkBash("block", "cat .env");
checkBash("block", "source .env && npm run dev");
checkBash("block", `python -c "print(open('.env').read())"`);
checkBash("block", "cat apps/api/.env.local");
checkBash("block", "less .env.production");
checkBash("block", "cat .env.development.local");
checkBash("block", "git add .env");
checkBash("block", "cp .env.example .env");
checkBash("block", "docker run --env-file=.env app");
checkBash("block", "cat $HOME/project/.env");
checkBash("block", "cat .env.example.local");
checkBash("block", "cat .env.example*");
checkBash("block", "cat .ENV");
checkBash("block", "cat .env-production");
checkBash("block", "cat .env_prod");
checkBash("block", "cat .env*");
// 引用符の中も検査する（ファイル名を書くだけなら -F / --body-file でファイル経由で渡す）
checkBash("block", `git commit -m "chore: .env を除外"`);

// --- 通るもの ---
checkBash("pass", "cat .env.example");
checkBash("pass", "cat .Env.Example");
checkBash("pass", "git commit -F msg.txt");
checkBash("pass", `node -e "console.log(process.env.HOME)"`);
checkBash("pass", "grep -r import.meta.env.VITE_API src");
checkBash("pass", "ls .envrc");
checkBash("pass", "source .venv/bin/activate");
checkBash("pass", "cat config/app.env");
checkBash("pass", "npm install dotenv");
checkBash("pass", "npm test");

// Bash 以外のツール（Read などは permissions.deny が担当する）
report(
    "pass",
    decide(JSON.stringify({ tool_name: "Read", tool_input: { file_path: "/x/.env" } })),
    "Read: /x/.env"
);

// 入力が壊れているときは通す
report("pass", decide("not json"), "壊れた JSON");
report("pass", decide(JSON.stringify({ tool_name: "Bash", tool_input: {} })), "command がない");
report("pass", decide("null"), "JSON が null");

console.log(`\n成功: ${passed} / 失敗: ${failed}`);
process.exit(failed === 0 ? 0 : 1);
