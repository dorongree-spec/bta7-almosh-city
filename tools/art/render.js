// Renders an HTML file to an image: node render.js <file.html> <out.png|jpg> <width> <height> [transparent]
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const [file, out, w, h, transparent] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.resolve(file));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);
  const opts = { path: out, omitBackground: transparent === 'transparent' };
  if (out.endsWith('.jpg')) { opts.type = 'jpeg'; opts.quality = 90; }
  await page.screenshot(opts);
  await browser.close();
})();
