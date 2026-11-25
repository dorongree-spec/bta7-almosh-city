// Small vector-illustration kit for the Almosh City posters. Everything
// returns SVG markup; scenes are composed in make_posters.js.
const OUT = '#170a28';
let _seed = 1;
function seed(s) { _seed = s; }
function rnd() { _seed = (_seed * 1664525 + 1013904223) % 4294967296; return _seed / 4294967296; }
function rr(a, b) { return a + (b - a) * rnd(); }
function pick(arr) { return arr[Math.floor(rnd() * arr.length)]; }

function defs(extra = '') {
  return `<defs>
  <filter id="grain" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="7" result="n"/>
    <feColorMatrix type="matrix" values="0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0 0.5  0.9 0.9 0.9 0 -0.75"/>
  </filter>
  <radialGradient id="vig" cx="50%" cy="46%" r="75%">
    <stop offset="0.55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#05010c" stop-opacity="0.72"/>
  </radialGradient>
  <filter id="soft"><feGaussianBlur stdDeviation="18"/></filter>
  <filter id="softer"><feGaussianBlur stdDeviation="46"/></filter>
  <filter id="glow"><feGaussianBlur stdDeviation="9" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  ${extra}</defs>`;
}

function sky(stops) {
  const id = 'sky' + Math.floor(rnd() * 1e6);
  const s = stops.map(([o, c]) => `<stop offset="${o}" stop-color="${c}"/>`).join('');
  return `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1">${s}</linearGradient><rect width="2560" height="1440" fill="url(#${id})"/>`;
}

function sun(cx, cy, r, c1, c2, stripes = true) {
  const id = 'sun' + Math.floor(rnd() * 1e6);
  let cuts = '';
  if (stripes) {
    let y = cy + r * 0.05, h = r * 0.03;
    while (y < cy + r) { cuts += `<rect x="${cx - r}" y="${y}" width="${2 * r}" height="${h}" fill="#000"/>`; y += h * 2.6 + r * 0.03; h *= 1.28; }
  }
  return `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient>
  <circle cx="${cx}" cy="${cy}" r="${r * 1.5}" fill="${c1}" opacity="0.28" filter="url(#softer)"/>
  <mask id="m${id}"><rect width="2560" height="1440" fill="#fff"/>${cuts}</mask>
  <circle cx="${cx}" cy="${cy}" r="${r}" fill="url(#${id})" mask="url(#m${id})"/>`;
}

function stars(n, maxY) {
  let s = '';
  for (let i = 0; i < n; i++) s += `<circle cx="${rr(0, 2560).toFixed(0)}" cy="${rr(0, maxY).toFixed(0)}" r="${rr(0.8, 2.6).toFixed(1)}" fill="#fff" opacity="${rr(0.3, 0.95).toFixed(2)}"/>`;
  return s;
}

// A row of far towers with lit windows.
function skyline(baseY, color, lit, minH, maxH, density = 1) {
  let s = '', x = -40;
  while (x < 2600) {
    const w = rr(70, 190), h = rr(minH, maxH) * (rnd() < 0.18 ? 1.7 : 1);
    if (rnd() < density) {
      s += `<rect x="${x.toFixed(0)}" y="${(baseY - h).toFixed(0)}" width="${w.toFixed(0)}" height="${(h + 4).toFixed(0)}" fill="${color}"/>`;
      if (lit) for (let wy = baseY - h + 14; wy < baseY - 14; wy += 22) for (let wx = x + 10; wx < x + w - 12; wx += 20)
        if (rnd() < 0.3) s += `<rect x="${wx.toFixed(0)}" y="${wy.toFixed(0)}" width="9" height="11" fill="${lit}" opacity="${rr(0.5, 1).toFixed(2)}"/>`;
    }
    x += w + rr(-10, 60);
  }
  return s;
}

// Solar water heater: the roofline signature of every Israeli block.
function dud(x, y, s, color) {
  return `<g transform="translate(${x} ${y}) scale(${s})" fill="${color}">
    <rect x="-4" y="-26" width="46" height="18" rx="9"/><rect x="2" y="-10" width="4" height="12"/><rect x="32" y="-10" width="4" height="12"/>
    <polygon points="40,2 86,2 96,-22 50,-22"/></g>`;
}
function antenna(x, y, h, color) {
  return `<g stroke="${color}" stroke-width="4" fill="none"><line x1="${x}" y1="${y}" x2="${x}" y2="${y - h}"/>
    <line x1="${x - 22}" y1="${y - h + 10}" x2="${x + 22}" y2="${y - h + 10}"/><line x1="${x - 15}" y1="${y - h + 24}" x2="${x + 15}" y2="${y - h + 24}"/><line x1="${x - 9}" y1="${y - h + 38}" x2="${x + 9}" y2="${y - h + 38}"/></g>`;
}

// A slab housing block ("shikun"): window grid, shutters, AC boxes, laundry, roof clutter.
function block(x, baseY, w, floors, o = {}) {
  const fh = o.fh || 78, h = floors * fh + 30, top = baseY - h;
  const wall = o.wall || '#3a2550', dark = o.dark || OUT, lit = o.lit || '#ffd77a', win = o.win || '#241438';
  let s = `<rect x="${x}" y="${top}" width="${w}" height="${h + 6}" fill="${wall}" stroke="${dark}" stroke-width="${o.sw || 8}"/>`;
  if (o.shade) s += `<rect x="${x}" y="${top}" width="${w * 0.22}" height="${h + 6}" fill="#000" opacity="0.18"/>`;
  const cols = Math.max(2, Math.floor(w / 96));
  const cw = w / cols;
  for (let f = 0; f < floors; f++) {
    const wy = top + 26 + f * fh;
    s += `<line x1="${x}" y1="${wy + fh - 22}" x2="${x + w}" y2="${wy + fh - 22}" stroke="${dark}" stroke-width="3" opacity="0.5"/>`;
    for (let c = 0; c < cols; c++) {
      const wx = x + c * cw + cw * 0.2, ww = cw * 0.6, wh = fh * 0.5;
      const on = rnd() < (o.litChance ?? 0.3);
      s += `<rect x="${wx.toFixed(0)}" y="${wy}" width="${ww.toFixed(0)}" height="${wh.toFixed(0)}" fill="${on ? lit : win}" stroke="${dark}" stroke-width="4"/>`;
      if (rnd() < 0.45) s += `<rect x="${wx.toFixed(0)}" y="${wy}" width="${ww.toFixed(0)}" height="${(wh * rr(0.3, 0.8)).toFixed(0)}" fill="${o.shutter || '#5b4a6e'}" stroke="${dark}" stroke-width="3"/>`;
      if (rnd() < 0.3) s += `<rect x="${(wx + ww - 6).toFixed(0)}" y="${(wy + wh + 4).toFixed(0)}" width="30" height="18" fill="${o.ac || '#b9b4c4'}" stroke="${dark}" stroke-width="3"/>`;
      if (rnd() < 0.2 && o.laundry !== false) {
        const ly = wy + wh + 10; let lx = wx;
        s += `<line x1="${wx.toFixed(0)}" y1="${ly}" x2="${(wx + ww).toFixed(0)}" y2="${ly}" stroke="${dark}" stroke-width="2"/>`;
        while (lx < wx + ww - 14) { s += `<rect x="${lx.toFixed(0)}" y="${ly}" width="12" height="${rr(14, 26).toFixed(0)}" fill="${pick(['#ff5d8f', '#fff', '#59d2c9', '#ffd35a'])}"/>`; lx += 17; }
      }
    }
  }
  let rx = x + 30;
  while (rx < x + w - 110) { s += rnd() < 0.7 ? dud(rx, top - 2, rr(0.8, 1.05), dark) : antenna(rx + 30, top, rr(60, 110), dark); rx += rr(110, 190); }
  return s;
}

function palm(x, baseY, sc, color = OUT, flip = 1) {
  return `<g transform="translate(${x} ${baseY}) scale(${sc * flip} ${sc})" fill="${color}">
    <path d="M0 0 C-6 -70 -2 -150 14 -235 L26 -233 C12 -150 10 -70 16 0 Z"/>
    <path d="M20 -236 C-20 -262 -70 -262 -112 -232 C-78 -246 -40 -244 -8 -226 Z"/>
    <path d="M20 -236 C-10 -282 -52 -306 -100 -302 C-62 -296 -30 -276 -4 -240 Z"/>
    <path d="M20 -236 C22 -286 46 -322 86 -338 C60 -312 46 -282 40 -238 Z"/>
    <path d="M20 -236 C60 -272 108 -278 150 -256 C112 -262 74 -252 42 -228 Z"/>
    <path d="M20 -236 C70 -240 112 -220 136 -184 C108 -208 72 -220 34 -220 Z"/>
    <path d="M20 -236 C-18 -232 -52 -210 -70 -176 C-48 -200 -18 -214 14 -218 Z"/></g>`;
}

function lamp(x, baseY, h, o = {}) {
  const dir = o.dir || 1, c = o.color || OUT, lx = x + dir * 70, ly = baseY - h + 8;
  const cone = o.light ? `<polygon points="${lx},${ly} ${lx - 330},${baseY + 30} ${lx + 330},${baseY + 30}" fill="${o.light}" opacity="${o.lightOpacity || 0.22}" filter="url(#soft)"/>
    <ellipse cx="${lx}" cy="${baseY + 8}" rx="330" ry="34" fill="${o.light}" opacity="0.3" filter="url(#soft)"/>` : '';
  return `${cone}<g stroke="${c}" stroke-width="12" fill="none" stroke-linecap="round"><path d="M${x} ${baseY} L${x} ${baseY - h + 26} Q${x} ${baseY - h} ${x + dir * 26} ${baseY - h} L${x + dir * 86} ${baseY - h}"/></g>
    <rect x="${Math.min(lx - 26, lx + 26) }" y="${baseY - h - 4}" width="52" height="16" rx="6" fill="${o.light || c}" ${o.light ? 'filter="url(#glow)"' : ''}/>`;
}

// Side view of a car. kind: sedan (boxy eighties saloon), hatch (with spoiler), pickup.
function car(kind, x, baseY, sc, o = {}) {
  const body = o.body || '#e9dcc0', glass = o.glass || '#2b1c44', flip = o.flip ? -1 : 1;
  const prof = {
    sedan: 'M-250 -62 L-246 -108 L-150 -116 L-112 -176 L70 -178 L128 -118 L236 -106 L252 -70 L250 -40 L-250 -40 Z',
    hatch: 'M-228 -60 L-224 -112 L-176 -128 L-150 -184 L60 -186 L130 -124 L214 -108 L232 -72 L230 -40 L-228 -40 Z',
    pickup: 'M-270 -62 L-268 -132 L-40 -132 L-36 -196 L96 -196 L150 -128 L256 -112 L270 -74 L268 -40 L-270 -40 Z',
  }[kind];
  const win = {
    sedan: 'M-132 -118 L-102 -164 L-22 -166 L-22 -118 Z M-8 -118 L-8 -166 L62 -166 L106 -118 Z',
    hatch: 'M-156 -126 L-138 -172 L-40 -174 L-40 -126 Z M-26 -126 L-26 -174 L54 -174 L108 -126 Z',
    pickup: 'M-24 -132 L-22 -184 L88 -184 L128 -132 Z',
  }[kind];
  const wheels = { sedan: [-150, 150], hatch: [-138, 138], pickup: [-170, 164] }[kind];
  let s = `<g transform="translate(${x} ${baseY}) scale(${sc * flip} ${sc})">`;
  s += `<ellipse cx="0" cy="2" rx="300" ry="18" fill="#000" opacity="0.45"/>`;
  if (o.neon) s += `<ellipse cx="0" cy="-4" rx="290" ry="26" fill="${o.neon}" opacity="0.9" filter="url(#soft)"/>`;
  if (o.beam) s += `<polygon points="246,-92 900,-150 900,10 246,-60" fill="${o.beam}" opacity="0.28" filter="url(#soft)"/>`;
  s += `<path d="${prof}" fill="${body}" stroke="${OUT}" stroke-width="10" stroke-linejoin="round"/>`;
  s += `<path d="${win}" fill="${glass}" stroke="${OUT}" stroke-width="6" stroke-linejoin="round"/>`;
  s += `<path d="M-250 -78 L250 -78" stroke="${OUT}" stroke-width="5" opacity="0.55"/>`;
  s += `<rect x="-252" y="-62" width="504" height="14" fill="#000" opacity="0.22"/>`;
  if (kind === 'hatch' && o.spoiler !== false) s += `<path d="M-236 -196 L-150 -200 L-150 -186 L-170 -186 L-176 -132 L-196 -130 L-196 -186 L-236 -184 Z" fill="${body}" stroke="${OUT}" stroke-width="8" stroke-linejoin="round"/>`;
  if (kind === 'pickup' && o.load) s += `<g stroke="${OUT}" stroke-width="7" stroke-linejoin="round"><rect x="-250" y="-190" width="90" height="58" fill="#8d6a4a"/><rect x="-158" y="-176" width="100" height="44" fill="#c9b08a"/><rect x="-236" y="-232" width="120" height="42" fill="#f4f1ea"/><path d="M-110 -176 q30 -60 60 0 z" fill="#3fae5a"/></g>`;
  s += `<rect x="236" y="-104" width="18" height="20" rx="4" fill="${o.lamp || '#fff3c0'}" ${o.beam ? 'filter="url(#glow)"' : ''}/>`;
  s += `<rect x="-256" y="-104" width="14" height="22" rx="3" fill="#ff3246" ${o.tail ? 'filter="url(#glow)"' : ''}/>`;
  for (const wx of wheels) s += `<circle cx="${wx}" cy="-38" r="46" fill="#120a1c" stroke="${OUT}" stroke-width="8"/><circle cx="${wx}" cy="-38" r="20" fill="${o.rim || '#9a93a8'}"/>`;
  return s + '</g>';
}

// Jointed figure. Coordinates in "units" (about 100 px tall per unit of scale):
// y grows downwards, feet at 0. pose maps joint names to [x, y].
function limb(a, b, w, fill) {
  return `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${OUT}" stroke-width="${w + 12}" stroke-linecap="round"/>` +
         `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${fill}" stroke-width="${w}" stroke-linecap="round"/>`;
}
const POSES = {
  stand: { hip: [0, -205], sh: [4, -355], head: [8, -410], elL: [-34, -280], haL: [-30, -205], elR: [40, -282], haR: [46, -208], knL: [-18, -105], ftL: [-22, 0], knR: [22, -105], ftR: [28, 0] },
  lean: { hip: [0, -200], sh: [-26, -348], head: [-22, -404], elL: [-70, -290], haL: [-30, -250], elR: [10, -280], haR: [-24, -246], knL: [10, -100], ftL: [56, 0], knR: [34, -104], ftR: [18, 0] },
  walk: { hip: [0, -205], sh: [10, -355], head: [18, -410], elL: [-24, -285], haL: [-52, -222], elR: [46, -286], haR: [78, -232], knL: [-34, -108], ftL: [-74, -6], knR: [40, -112], ftR: [64, 0] },
  sit: { hip: [0, -150], sh: [-14, -296], head: [-6, -352], elL: [-40, -224], haL: [10, -176], elR: [22, -226], haR: [70, -190], knL: [92, -156], ftL: [100, 0], knR: [104, -150], ftR: [128, 0] },
  point: { hip: [0, -205], sh: [4, -355], head: [10, -410], elL: [-34, -280], haL: [-26, -206], elR: [70, -340], haR: [140, -366], knL: [-18, -105], ftL: [-22, 0], knR: [22, -105], ftR: [28, 0] },
  hunch: { hip: [0, -170], sh: [34, -292], head: [62, -330], elL: [50, -232], haL: [108, -214], elR: [58, -236], haR: [112, -218], knL: [-8, -86], ftL: [-12, 0], knR: [14, -88], ftR: [20, 0] },
  arms: { hip: [0, -205], sh: [4, -355], head: [8, -410], elL: [-60, -372], haL: [-96, -440], elR: [66, -372], haR: [104, -440], knL: [-22, -105], ftL: [-30, 0], knR: [26, -105], ftR: [36, 0] },
};
function person(x, baseY, sc, pose, o = {}) {
  const flip = o.flip ? -1 : 1;
  if (!o.sil) return `<g transform="translate(${x} ${baseY}) scale(${sc * flip} ${sc})">${figure(pose, o)}</g>`;
  // Silhouette: one dark shape, with a thin rim of light on the side the sun or lamp is on.
  const rim = o.rim || '#ffb46a', dx = (o.rimDx ?? 5) * flip, dy = o.rimDy ?? -4;
  const dark = Object.assign({}, o, { flat: o.silColor || '#150a24' });
  const lit = Object.assign({}, o, { flat: rim, plain: true });
  return `<g transform="translate(${x} ${baseY}) scale(${sc * flip} ${sc})"><g transform="translate(${dx} ${dy})">${figure(pose, lit)}</g>${figure(pose, dark)}</g>`;
}

// o.flat paints the whole figure in one colour (silhouette); o.plain drops the accents too.
function figure(pose, o) {
  const p = POSES[pose], F = o.flat;
  const skin = F || o.skin || '#c98f66', shirt = F || o.shirt || '#f2efe9', pants = F || o.pants || '#2c4f8f', shoe = F || o.shoe || '#f4f4f4';
  const girth = o.girth || 1, ow = F ? 0 : 12, line = F || OUT;
  const lim = (a, b, w, fill) => (F ? '' : `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${OUT}" stroke-width="${w + 12}" stroke-linecap="round"/>`) +
    `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${fill}" stroke-width="${w + (F ? 8 : 0)}" stroke-linecap="round"/>`;
  let s = F ? '' : `<ellipse cx="10" cy="4" rx="90" ry="12" fill="#000" opacity="0.4"/>`;
  s += lim(p.sh, p.elL, 28, shirt) + lim(p.elL, p.haL, 24, o.sleeve === 'long' ? shirt : skin);
  s += lim(p.hip, p.knL, 40 * girth, pants) + lim(p.knL, p.ftL, 32, pants);
  s += `<ellipse cx="${p.ftL[0] + 14}" cy="${p.ftL[1] - 6}" rx="30" ry="14" fill="${shoe}" stroke="${line}" stroke-width="${F ? 0 : 6}"/>`;
  s += lim(p.hip, p.knR, 42 * girth, pants) + lim(p.knR, p.ftR, 34, pants);
  s += `<ellipse cx="${p.ftR[0] + 14}" cy="${p.ftR[1] - 6}" rx="30" ry="14" fill="${shoe}" stroke="${line}" stroke-width="${F ? 0 : 6}"/>`;
  // Torso: shoulders wider than the waist, which is what makes it read as a person.
  const ax = p.sh[0] - p.hip[0], ay = p.sh[1] - p.hip[1], len = Math.hypot(ax, ay), nx = -ay / len, ny = ax / len;
  const shW = 50 * girth, hipW = 38 * girth * (girth > 1.1 ? 1.25 : 1);
  const T = [[p.sh[0] + nx * shW, p.sh[1] + ny * shW], [p.sh[0] - nx * shW, p.sh[1] - ny * shW], [p.hip[0] - nx * hipW, p.hip[1] - ny * hipW + 14], [p.hip[0] + nx * hipW, p.hip[1] + ny * hipW + 14]];
  s += `<polygon points="${T.map(q => q.map(v => v.toFixed(1)).join(',')).join(' ')}" fill="${shirt}" stroke="${F ? shirt : OUT}" stroke-width="${F ? 26 : 12}" stroke-linejoin="round"/>`;
  if (o.dress) s += `<path d="M${p.hip[0] - 48 * girth} ${p.hip[1] - 20} L${p.hip[0] + 48 * girth} ${p.hip[1] - 20} L${p.hip[0] + 70 * girth} ${p.hip[1] + 120} L${p.hip[0] - 66 * girth} ${p.hip[1] + 120} Z" fill="${shirt}" stroke="${line}" stroke-width="10" stroke-linejoin="round"/>`;
  if (o.stripes && !o.plain) s += `<line x1="${p.hip[0] + 22}" y1="${p.hip[1]}" x2="${p.knR[0] + 20}" y2="${p.knR[1]}" stroke="#fff" stroke-width="5"/><line x1="${p.knR[0] + 18}" y1="${p.knR[1]}" x2="${p.ftR[0] + 18}" y2="${p.ftR[1] - 16}" stroke="#fff" stroke-width="5"/>`;
  if (o.logo && !o.plain) s += `<circle cx="${(p.hip[0] + p.sh[0]) / 2 + 6}" cy="${(p.hip[1] + p.sh[1]) / 2 - 20}" r="22" fill="${o.logo}" stroke="${OUT}" stroke-width="5"/>`;
  if (o.chain && !o.plain) s += `<path d="M${p.sh[0] - 22} ${p.sh[1] + 6} Q${p.sh[0] + 6} ${p.sh[1] + 54} ${p.sh[0] + 30} ${p.sh[1] + 6}" stroke="#ffd35a" stroke-width="6" fill="none"/>`;
  s += lim([p.sh[0] + 2, p.sh[1] - 4], [p.head[0], p.head[1] + 20], 24, skin);
  s += `<ellipse cx="${p.head[0]}" cy="${p.head[1]}" rx="32" ry="39" fill="${skin}" stroke="${line}" stroke-width="${F ? 0 : 10}"/>`;
  const hx = p.head[0], hy = p.head[1];
  const cloth = (c) => (o.plain ? F : c);
  if (o.head === 'keffiyeh') s += `<path d="M${hx - 40} ${hy - 6} Q${hx - 40} ${hy - 52} ${hx + 4} ${hy - 50} Q${hx + 40} ${hy - 48} ${hx + 36} ${hy - 12} L${hx + 30} ${hy - 16} L${hx - 26} ${hy - 14} L${hx - 34} ${hy + 60} L${hx - 58} ${hy + 64} Z" fill="${cloth('#f6f3ee')}" stroke="${o.plain ? F : OUT}" stroke-width="8" stroke-linejoin="round"/><path d="M${hx - 38} ${hy - 26} L${hx + 38} ${hy - 26}" stroke="${o.plain ? F : OUT}" stroke-width="9"/>`;
  else if (o.head === 'scarf') s += `<path d="M${hx - 40} ${hy + 30} Q${hx - 50} ${hy - 56} ${hx + 6} ${hy - 50} Q${hx + 44} ${hy - 44} ${hx + 30} ${hy - 6} L${hx - 10} ${hy - 20} L${hx - 14} ${hy + 44} Z" fill="${cloth(o.scarf || '#d8376b')}" stroke="${o.plain ? F : OUT}" stroke-width="8" stroke-linejoin="round"/>`;
  else if (o.head === 'cap') s += `<path d="M${hx - 36} ${hy - 14} Q${hx - 30} ${hy - 52} ${hx + 6} ${hy - 48} Q${hx + 36} ${hy - 44} ${hx + 36} ${hy - 16} L${hx + 70} ${hy - 12} L${hx + 68} ${hy - 4} L${hx - 36} ${hy - 6} Z" fill="${F ? (o.plain ? F : (o.capSil || F)) : (o.cap || '#111')}" stroke="${F || OUT}" stroke-width="8" stroke-linejoin="round"/>`;
  else s += `<path d="M${hx - 36} ${hy - 8} Q${hx - 40} ${hy - 50} ${hx + 2} ${hy - 48} Q${hx + 40} ${hy - 46} ${hx + 34} ${hy - 14} Q${hx + 6} ${hy - 30} ${hx - 24} ${hy - 18} Z" fill="${F || o.hair || '#1c1016'}" stroke="${F || OUT}" stroke-width="6" stroke-linejoin="round"/>`;
  if (o.shades && !F) s += `<rect x="${hx + 2}" y="${hy - 10}" width="34" height="13" rx="4" fill="#0a0610"/>`;
  s += lim(p.sh, p.elR, 30, shirt) + lim(p.elR, p.haR, 26, o.sleeve === 'long' ? shirt : skin);
  if (o.cig && !o.plain) s += `<line x1="${p.haR[0]}" y1="${p.haR[1] - 6}" x2="${p.haR[0] + 26}" y2="${p.haR[1] - 16}" stroke="#fff" stroke-width="5"/><circle cx="${p.haR[0] + 28}" cy="${p.haR[1] - 17}" r="6" fill="#ff7a2e" filter="url(#glow)"/>`;
  return s;
}

// The white plastic garden chair, side view.
function chair(x, baseY, sc, o = {}) {
  const c = o.color || '#fbfaf6', flip = o.flip ? -1 : 1;
  return `<g transform="translate(${x} ${baseY}) scale(${sc * flip} ${sc})" fill="${c}" stroke="${OUT}" stroke-width="9" stroke-linejoin="round">
    <path d="M-58 -310 Q-70 -180 -52 -150 L-30 -150 Q-44 -200 -34 -312 Z"/>
    <path d="M-60 -160 L70 -160 Q84 -160 82 -144 L80 -132 L-60 -132 Z"/>
    <path d="M-56 -132 L-66 0 L-46 0 L-32 -132 Z"/><path d="M56 -132 L70 0 L50 0 L36 -132 Z"/>
    <path d="M-50 -232 L50 -216 L50 -200 L-48 -214 Z"/><path d="M40 -216 L52 -216 L58 -160 L44 -160 Z"/></g>`;
}

function camel(x, baseY, sc, color = OUT, flip = 1) {
  const leg = (x1, x2) => `<path d="M${x1} -170 L${x2} -86 L${x2 + 4} 0" stroke="${color}" stroke-width="22" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
  return `<g transform="translate(${x} ${baseY}) scale(${sc * flip} ${sc})" fill="${color}">
    ${leg(-104, -116)}${leg(-70, -62)}${leg(84, 78)}${leg(112, 126)}
    <ellipse cx="0" cy="-196" rx="150" ry="62"/>
    <path d="M-96 -236 C-70 -318 40 -318 78 -236 Z"/>
    <path d="M104 -226 C150 -236 168 -300 176 -352 L214 -350 C212 -280 190 -196 124 -170 Z"/>
    <path d="M170 -350 C176 -384 214 -392 246 -380 L276 -366 C282 -352 270 -342 254 -344 L212 -340 Z"/>
    <path d="M186 -388 l8 -22 l10 20 z"/>
    <path d="M-146 -206 C-170 -190 -176 -150 -170 -110" stroke="${color}" stroke-width="9" fill="none" stroke-linecap="round"/></g>`;
}

function finish() {
  return `<rect width="2560" height="1440" fill="url(#vig)"/><rect width="2560" height="1440" filter="url(#grain)" opacity="0.5" style="mix-blend-mode:overlay"/>`;
}

function page(inner, extraDefs = '') {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:K;src:url('Karantina-Bold.ttf')}@font-face{font-family:Sec;src:url('SecularOne-Regular.ttf')}
html,body{margin:0;background:#000}svg{display:block}</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1440" viewBox="0 0 2560 1440">${defs(extraDefs)}${inner}${finish()}</svg></body></html>`;
}

module.exports = { OUT, seed, rnd, rr, pick, sky, sun, stars, skyline, block, palm, lamp, car, person, chair, camel, dud, antenna, page };
