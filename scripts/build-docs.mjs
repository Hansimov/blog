import { spawnSync } from "node:child_process"
import { createRequire } from "node:module"
import path from "node:path"
import { fileURLToPath } from "node:url"

const require = createRequire(import.meta.url)
const cli = path.join(path.dirname(require.resolve("vitepress/package.json")), "bin/vitepress.js")
const buildEnv = { ...process.env }

// VitePress keeps its SSR .temp directory whenever DEBUG is nonempty, even
// for unrelated inherited values such as "release". Isolate the build only.
for (const key of Object.keys(buildEnv)) {
  if (key.toUpperCase() === "DEBUG") delete buildEnv[key]
}

const result = spawnSync(process.execPath, [cli, "build", "docs", ...process.argv.slice(2)], {
  cwd: fileURLToPath(new URL("../", import.meta.url)),
  env: buildEnv,
  stdio: "inherit"
})

if (result.error) throw result.error
process.exitCode = result.status ?? 1
