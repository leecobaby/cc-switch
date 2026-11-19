// 用法：node shot.cjs <outDir> <data> <afterPort> <beforePort> [maxChapters]
// 对每条章节截三张：改动前（main，点目录里同一轮）、改动后（点章节）、改动后且展开全部过程。
let chromium;
try {
  ({ chromium } = require("playwright"));
} catch {
  ({ chromium } = require("playwright-core"));
}
const fs = require("fs");
const [outDir, data, afterPort, beforePort, max = "8"] = process.argv.slice(2);
fs.mkdirSync(outDir, { recursive: true });

const launch = async () => {
  try {
    return await chromium.launch();
  } catch {
    return await chromium.launch({ channel: "chrome" });
  }
};

const open = async (browser, port, query) => {
  const page = await browser.newPage({
    viewport: { width: 1440, height: 860 },
    deviceScaleFactor: 2,
    colorScheme: "light",
    locale: "zh-CN",
  });
  page.on("pageerror", (error) => console.log("PAGE ERROR", error.message));
  await page.goto(`http://localhost:${port}/__harness.html?data=${data}${query}`);
  await page.waitForFunction("window.__ready === true", null, { timeout: 120000 });
  await page.waitForSelector("[data-outline-turn]", { timeout: 120000 });
  await page.waitForTimeout(2500);
  return page;
};

const chapterButtons = (page) =>
  page.locator('nav [data-outline-turn] button:has(svg.lucide-pin), nav [data-outline-turn] button:has(svg.lucide-bookmark)');

(async () => {
  const browser = await launch();
  const after = await open(browser, afterPort, "&mode=after");
  const expanded = await open(browser, afterPort, "&mode=after&expand=1");
  const before = await open(browser, beforePort, "&mode=before");

  await before.screenshot({ path: `${outDir}/00-overview-before.png` });
  await after.screenshot({ path: `${outDir}/00-overview-after.png` });

  const total = await chapterButtons(after).count();
  console.log("chapters in outline:", total);
  // 章节多时均匀抽样
  const limit = Math.min(Number(max), total);
  const picks = [...new Set(Array.from({ length: limit }, (_, i) => Math.round((i * (total - 1)) / Math.max(1, limit - 1))))];
  let n = 0;
  for (const index of picks) {
    n += 1;
    const tag = String(n).padStart(2, "0");
    const button = chapterButtons(after).nth(index);
    const turn = await button.evaluate((el) => el.closest("[data-outline-turn]").getAttribute("data-outline-turn"));
    const title = (await button.innerText()).replace(/\s+/g, " ").trim();
    console.log(tag, `turn ${turn}`, title);

    await button.scrollIntoViewIfNeeded();
    await button.click();
    await after.waitForTimeout(1500);
    await after.screenshot({ path: `${outDir}/${tag}-after.png` });

    const expandedButton = chapterButtons(expanded).nth(index);
    await expandedButton.scrollIntoViewIfNeeded();
    await expandedButton.click();
    await expanded.waitForTimeout(1500);
    await expanded.screenshot({ path: `${outDir}/${tag}-after-expanded.png` });

    const entry = before.locator(`[data-outline-turn="${turn}"] button`).first();
    if (await entry.count()) {
      await entry.scrollIntoViewIfNeeded();
      await entry.click();
      await before.waitForTimeout(1500);
    }
    await before.screenshot({ path: `${outDir}/${tag}-before.png` });
  }

  // 只看章节的目录
  const toggle = after.locator("nav button[aria-pressed]").first();
  if (await toggle.count()) {
    await toggle.click();
    await after.waitForTimeout(800);
    await after.screenshot({ path: `${outDir}/99-chapters-only-after.png` });
  }
  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
