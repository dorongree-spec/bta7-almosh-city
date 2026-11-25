const fs = require('fs');
const L = require('./lib.js');
const scenes = {};

// 1. The hero and Dad's old saloon at golden hour, housing blocks behind.
scenes.hero = () => {
  L.seed(11);
  let s = L.sky([[0, '#2a1a5e'], [0.38, '#b23a7d'], [0.62, '#ff8a4a'], [0.8, '#ffd27a']]);
  s += L.sun(1800, 760, 300, '#fff1a8', '#ff5a6e');
  s += L.skyline(900, '#7a3170', null, 120, 300);
  s += L.block(-60, 1010, 760, 6, { wall: '#5a2c68', litChance: 0.12 });
  s += L.block(1500, 1010, 900, 5, { wall: '#4a245c', litChance: 0.1, shade: true });
  s += L.block(820, 990, 560, 4, { wall: '#6b3572', litChance: 0.08, fh: 66 });
  s += L.palm(1420, 1020, 1.9) + L.palm(2380, 1030, 2.3, L.OUT, -1) + L.palm(700, 1020, 1.5);
  s += `<rect x="0" y="1000" width="2560" height="440" fill="#2a1638"/><rect x="0" y="1000" width="2560" height="26" fill="#3c2150"/>`;
  s += `<polygon points="0,1120 2560,1060 2560,1440 0,1440" fill="#1d0f2a"/>`;
  s += `<g stroke="#ffd27a" stroke-width="10" opacity="0.7"><line x1="100" y1="1300" x2="420" y2="1290"/><line x1="700" y1="1282" x2="1020" y2="1272"/><line x1="1900" y1="1246" x2="2220" y2="1236"/></g>`;
  s += L.lamp(330, 1010, 520);
  s += L.car('sedan', 1290, 1250, 1.75, { body: '#e7d6b2', rim: '#b8b0a0' });
  s += L.person(700, 1300, 1.8, 'lean', { sil: true, rim: '#ffb46a', cig: true, flip: true });
  return s;
};

// 2. Three men on white plastic chairs outside a kiosk, at night.
scenes.chairs = () => {
  L.seed(23);
  let s = L.sky([[0, '#070616'], [0.55, '#1a1140'], [1, '#3a1d58']]);
  s += L.stars(160, 620);
  s += `<circle cx="2140" cy="250" r="70" fill="#fdf6d8" opacity="0.95"/><circle cx="2115" cy="235" r="70" fill="#0b0920"/>`;
  s += L.skyline(880, '#120c2c', '#ffd77a', 160, 420);
  s += L.block(-120, 1040, 700, 5, { wall: '#1b1338', litChance: 0.4, lit: '#ffc861' });
  s += L.block(1900, 1040, 760, 6, { wall: '#1f1540', litChance: 0.35, lit: '#7fe6ff' });
  s += `<rect x="0" y="1030" width="2560" height="410" fill="#150d28"/>`;
  // the kiosk
  s += `<g stroke="${L.OUT}" stroke-width="10" stroke-linejoin="round"><rect x="700" y="640" width="760" height="400" fill="#2b1d52"/><polygon points="660,640 1500,640 1560,560 600,560" fill="#e23a6e"/>
    <rect x="770" y="720" width="430" height="200" fill="#ffd77a"/><rect x="1250" y="720" width="150" height="320" fill="#1a1236"/></g>`;
  s += `<rect x="770" y="720" width="430" height="200" fill="#ffd77a" opacity="0.5" filter="url(#softer)"/>`;
  s += `<text x="1080" y="622" text-anchor="middle" font-family="K" font-size="92" fill="#fff" filter="url(#glow)" direction="rtl">קיוסק · פתוח 24/6</text>`;
  for (let i = 0; i < 9; i++) s += `<rect x="${790 + i * 45}" y="${745 + (i % 3) * 52}" width="30" height="40" fill="${L.pick(['#e23a6e', '#59d2c9', '#fff', '#ff8a4a'])}" stroke="${L.OUT}" stroke-width="4"/>`;
  s += L.lamp(480, 1040, 620, { light: '#ffd27a', lightOpacity: 0.3 });
  s += L.palm(2300, 1040, 1.8, L.OUT, -1);
  s += `<polygon points="0,1180 2560,1140 2560,1440 0,1440" fill="#0d0819"/>`;
  s += L.chair(620, 1290, 1.25) + L.person(640, 1290, 1.5, 'sit', { sil: true, rim: '#ffd27a', rimDx: -5, stripes: true, chain: true, cig: true });
  s += L.chair(1700, 1300, 1.25, { flip: true }) + L.person(1680, 1300, 1.5, 'sit', { sil: true, rim: '#ffd27a', stripes: true, flip: true, girth: 1.25, head: 'cap' });
  s += L.person(1180, 1330, 1.62, 'arms', { sil: true, rim: '#ffd27a', rimDx: -5, stripes: true, chain: true });
  s += L.chair(1010, 1040, 0.0001);
  s += `<g transform="translate(1180 760) rotate(-24)">${L.chair(0, 0, 1.15)}</g>`;
  return s;
};

// 3. The trader, his pickup and a camel, out where the road ends.
scenes.trader = () => {
  L.seed(31);
  let s = L.sky([[0, '#ffb347'], [0.5, '#ffd98a'], [0.75, '#fff0c2']]);
  s += L.sun(620, 430, 250, '#ffffff', '#ffe08a', false);
  s += `<path d="M0 900 Q500 780 1000 860 T2000 820 T2560 860 L2560 1440 L0 1440 Z" fill="#e8a45c"/>`;
  s += `<path d="M0 980 Q600 900 1300 960 T2560 930 L2560 1440 L0 1440 Z" fill="#d48a45"/>`;
  s += L.skyline(905, '#c9824a', null, 40, 130, 0.35);
  s += L.camel(1960, 1070, 1.45, '#7a3f22') + L.camel(2330, 1050, 1.0, '#8a4a28', -1);
  s += `<path d="M0 1090 Q900 1040 2560 1100 L2560 1440 L0 1440 Z" fill="#b86c33"/>`;
  s += `<polygon points="0,1210 2560,1170 2560,1440 0,1440" fill="#3a2230"/>`;
  s += L.car('pickup', 1240, 1300, 1.8, { body: '#f3efe6', load: true, rim: '#8c8478' });
  s += L.person(520, 1340, 1.78, 'point', { sil: true, silColor: '#3a1c18', rim: '#fff0c2', rimDx: -6, head: 'keffiyeh', sleeve: 'long' });
  s += `<g transform="translate(250 1340)"><ellipse cx="0" cy="-70" rx="120" ry="78" fill="#2f8f46" stroke="${L.OUT}" stroke-width="10"/><path d="M-70 -110 q70 -30 140 0 M-96 -70 q96 -34 192 0 M-80 -30 q80 -26 160 0" stroke="#1b5a2a" stroke-width="9" fill="none"/></g>`;
  return s;
};

// 4. The tuned hatchback under neon at a roundabout.
scenes.tuned = () => {
  L.seed(47);
  let s = L.sky([[0, '#05030f'], [0.5, '#1c0b3a'], [0.9, '#5a1466']]);
  s += L.stars(120, 560);
  s += L.skyline(900, '#150a30', '#ff5fa8', 200, 520);
  s += L.block(-80, 1030, 620, 7, { wall: '#1a1038', litChance: 0.45, lit: '#63f0ff' });
  s += L.block(2000, 1030, 640, 6, { wall: '#1d1240', litChance: 0.4, lit: '#ff7ab8' });
  s += `<rect x="0" y="1020" width="2560" height="420" fill="#100a22"/>`;
  // roundabout with a sculpture nobody asked for
  s += `<ellipse cx="1280" cy="1100" rx="620" ry="86" fill="#231645" stroke="${L.OUT}" stroke-width="10"/><ellipse cx="1280" cy="1092" rx="560" ry="70" fill="#2f7a4a"/>`;
  s += `<g stroke="${L.OUT}" stroke-width="10" stroke-linejoin="round" fill="#c9c4d6"><polygon points="1240,1080 1320,1080 1300,700 1260,700"/><circle cx="1280" cy="640" r="74"/><polygon points="1180,820 1380,780 1380,810 1180,850"/></g>`;
  s += L.palm(840, 1090, 1.5) + L.palm(1730, 1090, 1.7, L.OUT, -1);
  s += L.lamp(260, 1030, 600, { light: '#ff5fa8', lightOpacity: 0.25 }) + L.lamp(2330, 1030, 600, { light: '#63f0ff', lightOpacity: 0.25, dir: -1 });
  s += `<polygon points="0,1190 2560,1150 2560,1440 0,1440" fill="#0a0616"/>`;
  s += `<ellipse cx="1220" cy="1330" rx="760" ry="60" fill="#ff2e9a" opacity="0.35" filter="url(#softer)"/>`;
  s += L.car('hatch', 1220, 1320, 1.95, { body: '#f7f7fb', neon: '#ff2e9a', beam: '#bff7ff', tail: true, rim: '#ffd35a', lamp: '#dffbff' });
  s += L.person(420, 1350, 1.7, 'stand', { sil: true, rim: '#ff5fa8', rimDx: -6, logo: '#ffd35a', stripes: true });
  s += L.person(2200, 1360, 1.6, 'lean', { sil: true, rim: '#63f0ff', head: 'cap', flip: false, chain: true });
  return s;
};

// 5. Grandma, the shopping cart and the block that never got a lift.
scenes.grandma = () => {
  L.seed(59);
  let s = L.sky([[0, '#5ec8ff'], [0.6, '#bfeaff'], [1, '#fff3d0']]);
  s += `<g fill="#fff" opacity="0.9"><ellipse cx="500" cy="230" rx="230" ry="46"/><ellipse cx="640" cy="200" rx="150" ry="42"/><ellipse cx="2050" cy="320" rx="260" ry="44"/></g>`;
  s += L.skyline(960, '#9ad0e8', null, 80, 240, 0.6);
  s += L.block(380, 1090, 1500, 6, { wall: '#f0d9a8', win: '#3b3158', shutter: '#7fa0b8', lit: '#3b3158', litChance: 0, fh: 122, sw: 10 });
  s += L.block(1960, 1090, 800, 5, { wall: '#e6c690', win: '#3b3158', shutter: '#a9c18f', lit: '#3b3158', litChance: 0, fh: 122, sw: 10, shade: true });
  s += L.block(-420, 1090, 720, 5, { wall: '#ead0a0', win: '#3b3158', shutter: '#c98f7a', lit: '#3b3158', litChance: 0, fh: 122, sw: 10 });
  s += L.palm(330, 1100, 2.2, '#2f6b3a') + L.palm(1930, 1100, 2.0, '#2f6b3a', -1);
  s += `<rect x="0" y="1080" width="2560" height="360" fill="#d9b98a"/><polygon points="0,1210 2560,1180 2560,1440 0,1440" fill="#6a5a6e"/>`;
  s += `<rect x="0" y="1196" width="2560" height="20" fill="#f1ead8"/>`;
  s += L.person(1000, 1370, 1.75, 'hunch', { head: 'scarf', scarf: '#d8376b', shirt: '#7a3fa0', pants: '#3a2a4a', dress: true, skin: '#e8c3a4', girth: 1.3, sleeve: 'long', shoe: '#3a2a4a' });
  s += `<g transform="translate(1230 1370)" stroke="${L.OUT}" stroke-width="10" stroke-linejoin="round"><rect x="-10" y="-300" width="170" height="230" rx="16" fill="#3fa0c8"/><path d="M0 -240 L150 -240 M0 -180 L150 -180 M0 -120 L150 -120" stroke-width="6"/><line x1="-10" y1="-300" x2="-50" y2="-380"/><circle cx="30" cy="-34" r="34" fill="#22162e"/><circle cx="130" cy="-34" r="34" fill="#22162e"/><path d="M30 -320 q20 -70 60 -10 z" fill="#57b85f"/><rect x="80" y="-350" width="60" height="50" fill="#f6e7b0"/></g>`;
  s += L.person(1900, 1380, 1.6, 'walk', { shirt: '#74a03a', pants: '#3a4a5a', skin: '#d8a880', hair: '#3a2416', flip: true });
  s += `<g transform="translate(1900 1380) scale(-1.6 1.6)"><rect x="-56" y="-360" width="56" height="120" rx="14" fill="#34405a" stroke="${L.OUT}" stroke-width="9"/></g>`;
  return s;
};

// 6. The city at dusk, wide.
scenes.skyline = () => {
  L.seed(71);
  let s = L.sky([[0, '#1b1450'], [0.4, '#8a2f86'], [0.65, '#ff6f61'], [0.82, '#ffc36a']]);
  s += L.stars(70, 380);
  s += L.sun(1280, 880, 380, '#fff3a8', '#ff4f7a');
  s += L.skyline(930, '#a8407c', null, 120, 330);
  s += L.skyline(990, '#6a2a6e', '#ffe39a', 160, 470);
  s += L.skyline(1060, '#3a1a50', '#ffd77a', 120, 300);
  for (const [x, sc] of [[150, 1.6], [520, 1.2], [980, 1.5], [1650, 1.4], [2050, 1.7], [2420, 1.3]]) s += L.palm(x, 1090, sc, '#1c0d2c', x % 2 ? 1 : -1);
  s += `<rect x="0" y="1070" width="2560" height="370" fill="#1c0d2c"/>`;
  s += `<path d="M900 1440 L1210 1080 L1350 1080 L1660 1440 Z" fill="#2c1740"/><g stroke="#ffd27a" stroke-width="9" opacity="0.8"><line x1="1280" y1="1100" x2="1280" y2="1150"/><line x1="1280" y1="1190" x2="1280" y2="1270"/><line x1="1280" y1="1330" x2="1280" y2="1440"/></g>`;
  s += L.lamp(840, 1250, 560, { light: '#ffd27a' }) + L.lamp(1720, 1250, 560, { light: '#ffd27a', dir: -1 });
  s += L.camel(400, 1262, 0.95, '#120820');
  s += L.chair(2180, 1330, 1.1);
  return s;
};

for (const [name, fn] of Object.entries(scenes)) fs.writeFileSync(`poster_${name}.html`, L.page(fn()));
console.log(Object.keys(scenes).join(' '));
