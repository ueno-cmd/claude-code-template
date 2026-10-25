// guard-env.js
// .env（秘密情報のファイル）に触れる Bash コマンドを実行前に止める PreToolUse フック（対象: Bash）
// Read・Edit・Grep などのツールは settings.json の permissions.deny で止める。
// このフックは deny で止められない Bash からの読み取り（source .env、スクリプトから開くなど）を補う
//
//   止める : コマンドに .env / .env.local / .env-prod などのファイル名が出てくる（.env.example は除く）
//            引用符の中も検査する（python -c "open('.env')" を止めるため）
//   通す   : それ以外。入力が読めないときも通す（主な防御は deny なので、フックの不具合で作業を止めない）
//
// 止めるときは exit 2 で終了する。stderr の内容が理由として Claude に渡り、作業は止まらない
// .e"n"v のように引用符やワイルドカードで書き換えた書き方は対象外（うっかりミスを止めるのが目的）

// .env で始まるファイル名（. - _ で続く名前とワイルドカードを含む）。大文字小文字は区別しない
// 単語の途中にあるもの（process.env.X・.envrc・.venv など）は除く
const ENV_FILE_RE = /(?<![\w.])\.env(?:[._-][\w.*?[\]-]*)?(?!\w)/gi;

// AI が読んでよい見本ファイル
const ALLOWED = new Set([".env.example"]);

async function main() {
    const chunks = [];
    for await (const chunk of process.stdin) {
        chunks.push(chunk);
    }

    let toolArgs;
    try {
        toolArgs = JSON.parse(Buffer.concat(chunks).toString());
    } catch {
        return;
    }
    if (toolArgs?.tool_name !== "Bash") return;

    const command = toolArgs.tool_input?.command;
    if (typeof command !== "string") return;

    const found = [...new Set(command.match(ENV_FILE_RE) || [])].filter(
        (name) => !ALLOWED.has(name.toLowerCase())
    );
    if (found.length > 0) {
        console.error(
            `🚫 秘密情報のファイル（${found.join(", ")}）に触れるコマンドをブロックしました。` +
                "中身が必要な場合はユーザーに依頼してください。変数名の確認には .env.example を使えます。" +
                "コミットメッセージや PR 本文にファイル名を書くだけなら、git commit -F や gh pr create --body-file でファイル経由で渡してください。"
        );
        process.exit(2);
    }
}

main();
