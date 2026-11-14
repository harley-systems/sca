// Renders film.html to images with headless Chrome. film.html draws any moment through window.setTime(t).
//   node render.js stills 5,20,45   -> build/stills/t_<seconds>.png, to check a change
//   node render.js frames           -> build/frames/f_00000.jpg ..., every frame; skips the ones already there
// CHROME names the browser (default /usr/bin/google-chrome).
const puppeteer = require('puppeteer-core');
const path = require('path'), fs = require('fs');
const FPS = 30, END = 120, W = 1920, H = 1080;
const url = 'file://' + path.join(__dirname, 'film.html');

async function open(browser) {
  const p = await browser.newPage();
  await p.setViewport({ width: W, height: H, deviceScaleFactor: 1 });
  await p.goto(url);
  await p.evaluate(() => window.ready);
  return p;
}
const launch = () => puppeteer.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', headless: 'new', protocolTimeout: 600000,
  args: ['--allow-file-access-from-files', '--force-color-profile=srgb', '--hide-scrollbars'] });
(async () => {
  const mode = process.argv[2];
  if (mode === 'stills') {
    const browser = await launch();
    const p = await open(browser);
    fs.mkdirSync('build/stills', { recursive: true });
    for (const s of process.argv[3].split(',')) {
      await p.evaluate(t => window.setTime(t), +s);
      await p.screenshot({ path: `build/stills/t_${s}.png` });
    }
    await browser.close();
  } else {
    fs.mkdirSync('build/frames', { recursive: true });
    const total = FPS * END, NW = 8;
    let next = 0, done = 0;
    // one browser per worker: a tab in the background doesn't paint, so its screenshot never returns
    await Promise.all([...Array(NW)].map(async () => {
      const browser = await launch();
      const p = await open(browser);
      while (next < total) {
        const i = next++;
        const f = `build/frames/f_${String(i).padStart(5, '0')}.jpg`;
        if (!fs.existsSync(f)) {
          await p.evaluate(t => window.setTime(t), i / FPS);
          await p.screenshot({ path: f + '.tmp.jpg', type: 'jpeg', quality: 96 });
          fs.renameSync(f + '.tmp.jpg', f);
        }
        if (++done % 300 === 0) console.log(done, '/', total);
      }
      await browser.close();
    }));
  }
})();
