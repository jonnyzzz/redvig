const { readFile, writeFile } = require('node:fs/promises');
const { join } = require('node:path');
const sharp = require('sharp');

const assets = join(__dirname, 'assets');
const paper = '#FBF8F3';
const ink = '#221F1C';
const muted = '#62574F';
const line = '#DBD2C7';
const signal = '#E34A3C';
const soft = '#F1E9DF';

function svg(width, height, title, contents) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img">
  <title>${title}</title>
${contents}
</svg>
`;
}

async function writeSvg(name, source) {
  await writeFile(join(assets, name), source);
}

function raster(source, width, height) {
  return sharp(Buffer.from(source)).resize(width, height).png().toBuffer();
}

async function writePng(name, source, width, height) {
  await writeFile(join(assets, name), await raster(source, width, height));
}

async function writeFavicon(mark) {
  const sizes = [16, 32, 48];
  const pngs = await Promise.all(sizes.map(size => raster(mark, size, size)));
  const header = Buffer.alloc(6 + sizes.length * 16);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  for (const [index, size] of sizes.entries()) {
    const entry = 6 + index * 16;
    header[entry] = size;
    header[entry + 1] = size;
    header.writeUInt16LE(1, entry + 4);
    header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(pngs[index].length, entry + 8);
    header.writeUInt32LE(offset, entry + 12);
    offset += pngs[index].length;
  }
  await writeFile(join(assets, 'favicon.ico'), Buffer.concat([header, ...pngs]));
}

async function buildAssets() {
  const markSource = await readFile(join(__dirname, 'logos', '01-aperture.svg'), 'utf8');
  const wordSource = await readFile(join(__dirname, 'logos', 'wordmark.svg'), 'utf8');
  // The approved mark and outlined wordmark are the masters for every export.
  const markPath = markSource.match(/<path\b[^>]*\bd="([^"]+)"/)[1];
  const wordPaths = wordSource.match(/^    <path .+$/gm).join('\n');
  const markShape = color => `  <path fill="${color}" d="${markPath}"/>`;
  const wordShape = (color, transform) => `  <g fill="${color}" transform="${transform}">
${wordPaths}
  </g>`;
  const lockupShape = (markColor, wordColor) => `${markShape(markColor)}
${wordShape(wordColor, 'translate(70 1)')}`;

  for (const [name, markColor, wordColor] of [
    ['logo-light.svg', signal, ink],
    ['logo-dark.svg', signal, paper],
    ['logo-ink.svg', ink, ink],
    ['logo-white.svg', '#FFFFFF', '#FFFFFF'],
  ]) {
    const logo = svg(261, 64, 'redvig', lockupShape(markColor, wordColor));
    await writeSvg(name, logo);
    if (name === 'logo-light.svg' || name === 'logo-dark.svg') {
      await writePng(name.replace('.svg', '.png'), logo, 783, 192);
    }
  }

  const mark = svg(64, 64, 'redvig Aperture', markShape(signal));
  const appIcon = svg(512, 512, 'redvig app icon', `  <rect width="512" height="512" fill="${paper}"/>
  <g transform="translate(64 64) scale(6)">
${markShape(signal)}
  </g>`);
  await Promise.all([
    writeSvg('mark.svg', mark),
    writeSvg('mark-ink.svg', svg(64, 64, 'redvig Aperture', markShape(ink))),
    writeSvg('mark-white.svg', svg(64, 64, 'redvig Aperture', markShape('#FFFFFF'))),
    writeSvg('app-icon.svg', appIcon),
    writePng('mark-512.png', mark, 512, 512),
    writeFavicon(mark),
    writePng('favicon-32.png', mark, 32, 32),
    writePng('apple-touch-icon.png', appIcon, 180, 180),
    writePng('avatar-512.png', appIcon, 512, 512),
  ]);

  // The share card uses the same paper, ink and pencil accents as the homepage.
  const card = svg(1200, 630, 'redvig — Give your coding agent a real IDE', `  <rect width="1200" height="630" fill="${paper}"/>
  <path d="M61 135H1139M61 544H1139" stroke="${line}"/>
  <g transform="translate(54 55) scale(.9)">
${lockupShape(signal, ink)}
  </g>
  <rect x="801" y="190" width="350" height="304" rx="9" fill="${soft}"/>
  <rect x="790" y="179" width="350" height="304" rx="9" fill="${ink}"/>
  <g transform="translate(859 225) scale(3.3125)">
${markShape(signal)}
  </g>
  <g fill="${ink}" font-family="system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif" font-size="78" font-weight="700" letter-spacing="-2.8">
    <text x="56" y="286">Give your coding</text>
    <text x="56" y="377">agent a real IDE.</text>
  </g>
  <g fill="none" stroke="${signal}" stroke-linecap="round">
    <path d="M323 400c61-6 176-10 263-5" stroke-width="4"/>
    <path d="M341 406c64-5 161-7 231-5" opacity=".65" stroke-width="1.6"/>
  </g>
  <g fill="${muted}" font-family="system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif" font-size="22">
    <text x="61" y="469">Refactors, inspections, debugging, and real test runs.</text>
    <text x="1139" y="584" text-anchor="end" font-size="21" font-weight="700">redvig.dev</text>
  </g>`);
  await Promise.all([
    writeSvg('social-card.svg', card),
    writePng('social-card.png', card, 1200, 630),
  ]);
}

buildAssets().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
