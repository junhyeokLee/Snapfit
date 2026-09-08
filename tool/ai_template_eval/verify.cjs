const { chromium } = require("playwright");
const { PNG } = require("pngjs");
const fs = require("node:fs/promises");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const assert = require("node:assert/strict");
const { build } = require("./build.cjs");

async function main() {
  assert(process.argv[2], "Pass the fixture evaluation output directory");
  const out = path.resolve(process.argv[2]), report = await build(out);
  assert.equal(
    report.mode,
    "fixture",
    "UI checks use only explicit fixture reports",
  );
  assert.equal(report.results.length, 6);
  assert.equal(
    report.results.filter((r) => r.render.status === "passed").length,
    4,
  );
  assert.equal(
    report.results.find((r) => r.id === "fixture-font-overflow").render.status,
    "text_overflow",
  );
  const qa = path.join(out, "qa");
  await fs.mkdir(qa, { recursive: true });
  let checks = 0;
  const errors = [];
  const browser = await chromium.launch({ headless: true, channel: "chrome" });
  try {
    for (
      const [width, height] of [[1440, 1000], [390, 844], [844, 390], [
        320,
        568,
      ]]
    ) {
      const page = await browser.newPage({ viewport: { width, height } });
      page.on("pageerror", (e) => errors.push(e.message));
      page.on("console", (msg) => {
        if (msg.type() === "error") errors.push(msg.text());
      });
      await page.goto(pathToFileURL(path.join(out, "index.html")).href);
      await page.evaluate(() => document.fonts.ready);
      async function loaded() {
        await page.waitForFunction(() =>
          [...document.images].every((i) => i.complete && i.naturalWidth > 0)
        );
        assert(
          await page.evaluate(() =>
            document.documentElement.scrollWidth <= innerWidth + 1
          ),
          `Viewport overflow ${width}`,
        );
        checks++;
      }
      await loaded();
      assert.equal(
        await page.locator("#view").inputValue(),
        width <= 640 ? "single" : "spread",
      );
      await page.locator("#view").selectOption("spread");
      assert(
        (await page.locator("#mode").textContent()).includes(
          "실제 AI 생성 결과가 아닙니다",
        ),
      );
      assert(await page.locator("svg.lucide").count() > 0);
      for (const result of report.results) {
        await page.locator(`[data-id="${result.id}"]`).click();
        await loaded();
        if (result.render.status === "not_generated") {
          assert(await page.locator("#empty").isVisible());
          assert(await page.locator("#zoom").isDisabled());
          continue;
        }
        for (let group = 0; group < 3; group++) {
          await page.locator(".thumb").nth(group).click();
          await loaded();
          assert.equal(
            await page.locator("#book img").count(),
            group === 0 ? 1 : 2,
          );
          const book = await page.locator("#book").boundingBox(),
            stage = await page.locator("#stage").boundingBox();
          const ratio = result.render.canvas.width /
            result.render.canvas.height * (group === 0 ? 1 : 2);
          assert(
            Math.abs(book.width / book.height - ratio) < .01,
            "Album aspect preserved",
          );
          assert(book.width > 100 && book.height > 60);
          assert(
            book.x >= stage.x && book.y >= stage.y &&
              book.x + book.width <= stage.x + stage.width + 1 &&
              book.y + book.height <= stage.y + stage.height + 1,
          );
        }
      }
      await page.locator('[data-id="fixture-landscape"]').click();
      await page.locator("#next").click();
      await loaded();
      await page.screenshot({
        path: path.join(qa, `review-${width}x${height}.png`),
        fullPage: true,
      });
      await page.locator("#photos").uncheck();
      await loaded();
      assert(
        (await page.locator("#book img").first().getAttribute("src")).includes(
          "_empty_",
        ),
      );
      await page.locator("#photos").check();
      await page.locator("#view").selectOption("single");
      await loaded();
      assert.equal(await page.locator("#book img").count(), 1);
      await page.locator("#zoom").click();
      await loaded();
      assert(await page.locator("#zoom-dialog").isVisible());
      await page.locator("#close-zoom").click();
      await page.locator("#view").selectOption("spread");
      await page.locator("#filter").selectOption("failed");
      assert.equal(await page.locator(".case").count(), 2);
      await page.locator('[data-id="fixture-font-overflow"]').click();
      assert(
        await page.locator('#verdict option[value="approve"]').isDisabled(),
      );
      assert(
        (await page.locator("#issues").textContent()).includes("cover-title"),
      );
      await page.locator("#filter").selectOption("passed");
      assert.equal(await page.locator(".case").count(), 4);
      await page.locator('[data-id="fixture-square"]').click();
      await page.locator("#reviewer").fill("로컬 자동화 검증");
      await page.locator("#verdict").selectOption("approve");
      await page.locator("#save").click();
      assert((await page.locator("#saved").textContent()).includes("4점 이상"));
      for (const key of ["intent", "typography", "spread", "distinctiveness"]) {
        await page.locator(`[data-score="${key}"]`).selectOption("4");
      }
      await page.locator("#notes").fill(
        "브라우저 기능 테스트용 기록. 실제 디자인 판정 아님.",
      );
      await page.locator("#save").click();
      assert(
        (await page.locator("#saved").textContent()).includes("저장했습니다"),
      );
      await page.reload();
      await page.locator('[data-id="fixture-square"]').click();
      assert.equal(
        await page.locator("#notes").inputValue(),
        "브라우저 기능 테스트용 기록. 실제 디자인 판정 아님.",
      );
      const downloadPromise = page.waitForEvent("download");
      await page.locator("#export").click();
      const download = await downloadPromise;
      await download.saveAs(path.join(qa, `test-review-${width}.json`));
      const exported = JSON.parse(
        await fs.readFile(path.join(qa, `test-review-${width}.json`), "utf8"),
      );
      assert.equal(exported.mode, "fixture");
      assert.equal(exported.reviewFingerprint, report.reviewFingerprint);
      await page.evaluate(() => {
        window.EVALUATION.results.find((r) => r.id === "fixture-square").brief
          .prompt = '<img src=x onerror="window.INJECTED=true">';
      });
      await page.locator('[data-id="fixture-portrait"]').click();
      await page.locator('[data-id="fixture-square"]').click();
      assert.equal(await page.locator("#prompt img").count(), 0);
      assert.equal(await page.evaluate(() => window.INJECTED), undefined);
      await page.close();
    }
    for (const result of report.results) {
      for (const entry of result.render.pages) {
        const photo = PNG.sync.read(
            await fs.readFile(path.join(out, entry.photo)),
          ),
          empty = PNG.sync.read(await fs.readFile(path.join(out, entry.empty)));
        assert.equal(photo.width, empty.width);
        assert.equal(photo.height, empty.height);
        let different = 0;
        for (let i = 0; i < photo.data.length; i += 4) {
          if (
            Math.abs(photo.data[i] - empty.data[i]) +
                Math.abs(photo.data[i + 1] - empty.data[i + 1]) +
                Math.abs(photo.data[i + 2] - empty.data[i + 2]) > 40
          ) {
            different++;
          }
        }
        const fraction = different / (photo.width * photo.height);
        assert(
          entry.photoCount > 0 ? fraction > .025 : fraction === 0,
          `${result.id}/${entry.index}: actual photo pixels`,
        );
        checks++;
      }
    }
    assert.deepEqual(errors, []);
    await fs.writeFile(
      path.join(qa, "report.json"),
      JSON.stringify(
        {
          checks,
          errors,
          viewports: 4,
          provenance: "fixture-only browser and pixel checks",
        },
        null,
        2,
      ),
    );
    console.log(`${checks} checks passed`);
  } finally {
    await browser.close();
  }
}
main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
