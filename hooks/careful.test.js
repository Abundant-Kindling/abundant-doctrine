// Runs each fixture through careful.js as a real child process and compares
// the exit code (0 = allow, 2 = block) against the expected verdict.
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Fixtures live in a data file, not inline: careful.js pattern-matches the raw
// command string, so a harness whose test cases were literal dangerous commands
// would block its own invocation.
const HOOK = path.join(__dirname, 'careful.js');
const cases = JSON.parse(fs.readFileSync(path.join(__dirname, 'careful.test.cases.json'), 'utf-8'));

let failures = 0;
for (const [command, expected] of cases) {
  let actual = 'ALLOW';
  try {
    execFileSync('node', [HOOK], { input: JSON.stringify({ tool_input: { command } }), stdio: 'pipe' });
  } catch {
    actual = 'BLOCK';
  }
  const ok = actual === expected;
  if (!ok) failures++;
  console.log(`${ok ? 'ok  ' : 'FAIL'} | expected ${expected} got ${actual} | ${command}`);
}
// SQL sent through the Supabase MCP tools: [toolName, query, expected].
const mcpCases = JSON.parse(fs.readFileSync(path.join(__dirname, 'careful.mcp.cases.json'), 'utf-8'));
for (const [tool_name, query, expected] of mcpCases) {
  let actual = 'ALLOW';
  try {
    execFileSync('node', [HOOK], { input: JSON.stringify({ tool_name, tool_input: { project_id: 'x', query } }), stdio: 'pipe' });
  } catch {
    actual = 'BLOCK';
  }
  const ok = actual === expected;
  if (!ok) failures++;
  console.log(`${ok ? 'ok  ' : 'FAIL'} | expected ${expected} got ${actual} | ${tool_name} | ${JSON.stringify(query)}`);
}
const total = cases.length + mcpCases.length;
console.log(failures === 0 ? `\nall ${total} cases pass` : `\n${failures} FAILING`);
process.exit(failures === 0 ? 0 : 1);
