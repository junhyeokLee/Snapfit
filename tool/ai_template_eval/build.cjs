const fs = require("node:fs/promises");
const path = require("node:path");
const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");

async function build(directory) {
  const run = JSON.parse(
    await fs.readFile(path.join(directory, "run.json"), "utf8"),
  );
  const render = JSON.parse(
    await fs.readFile(path.join(directory, "render.json"), "utf8"),
  );
  assert.equal(run.schemaVersion, 1);
  assert.equal(render.runId, run.id);
  assert.equal(render.mode, run.mode);
  assert(["live", "fixture"].includes(run.mode));
  const results = run.results.map((result) => {
    const output = render.results.find((r) => r.id === result.id);
    assert(output, `Missing render status for ${result.id}`);
    for (const page of output.pages) {
      for (const mode of ["photo", "empty"]) {
        assert(
          /^renders\/[a-z0-9_-]+\.png$/.test(page[mode]),
          "Only generated local PNG paths allowed",
        );
      }
    }
    return { ...result, render: output };
  });
  const hash = createHash("sha256").update(JSON.stringify(render));
  for (const result of results) {
    for (const page of result.render.pages) {
      for (const mode of ["photo", "empty"]) {
        hash.update(await fs.readFile(path.join(directory, page[mode])));
      }
    }
  }
  const report = { ...run, results, reviewFingerprint: hash.digest("hex") };
  const json = JSON.stringify(report).replace(/</g, "\\u003c").replace(
    /\u2028/g,
    "\\u2028",
  ).replace(/\u2029/g, "\\u2029");
  await fs.writeFile(
    path.join(directory, "report.js"),
    `window.EVALUATION=${json};\n`,
    { mode: 0o600 },
  );
  await fs.copyFile(
    path.join(__dirname, "index.html"),
    path.join(directory, "index.html"),
  );
  await fs.copyFile(
    require.resolve("lucide/dist/umd/lucide.min.js"),
    path.join(directory, "lucide.js"),
  );
  await fs.copyFile(
    path.resolve(__dirname, "../../assets/fonts/NotoSansKR-Regular.ttf"),
    path.join(directory, "review-font.ttf"),
  );
  return report;
}
module.exports = { build };
if (require.main === module) {
  if (!process.argv[2]) throw new Error("Pass an evaluation output directory");
  build(path.resolve(process.argv[2])).then(() =>
    console.log(path.resolve(process.argv[2], "index.html"))
  ).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
