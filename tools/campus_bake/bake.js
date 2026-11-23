// Bakes the NAICOL REACTOR campus of ancientplanesimulator_DEV.html into a Godot-friendly scene dump
// by running the original code (with the original three.js) headlessly.
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { createCanvas } = require('@napi-rs/canvas');

const HTML = process.argv[2];
const OUT = process.argv[3];
fs.mkdirSync(path.join(OUT, 'tex'), { recursive: true });
const L = fs.readFileSync(HTML, 'utf8').split('\n');
const seg = (a, b) => L.slice(a - 1, b).join('\n');

// ---------------------------------------------------------------- environment
global.window = global;
global.self = global;
global.performance = { now: () => Date.now() };
const mkEl = (t) => {
  if (t === 'canvas') return createCanvas(300, 150);
  return { style: {}, appendChild() {}, setAttribute() {}, getContext() { return null; }, addEventListener() {}, classList: { add() {}, remove() {} } };
};
global.document = { createElement: mkEl, createElementNS: (ns, t) => mkEl(t), body: mkEl('div'), head: mkEl('div'), getElementById: () => null };
global.navigator = { userAgent: 'node' };
global.localStorage = { getItem: () => null, setItem() {} };
const stubFn = () => stub;
const stub = new Proxy(function () {}, { get: (t, k) => (k === Symbol.toPrimitive ? () => 0 : stub), apply: () => stub, construct: () => stub, set: () => true });

// three.js r128
vm.runInThisContext(L[958], { filename: 'three.js' });
global.THREE = global.THREE || window.THREE;

for (const n of ['AUD', 'UI', 'W3', 'AC', 'STORM', 'DMG', 'SYS', 'NCWALK', 'CINE', 'MENU', 'INV', 'NCPOLISH', 'NCV', 'CR0']) global[n] = stub;
global.NCUI = { infos: null, read() {}, open() {}, hud: stub };
global.clamp = (x, a, b) => (x < a ? a : x > b ? b : x);

let src = '';
src += seg(2460, 4000) + '\n';
src += seg(4197, 4208) + '\n';
src += seg(4227, 4233) + '\n';
src = src.replace('const NCUI_PLACEHOLDER', '');
fs.writeFileSync(path.join(OUT, '_game.js'), src);
vm.runInThisContext(src + '\n;NCUI.infos = NCINFO;', { filename: 'game.js' });
console.log('game code loaded; chunks:', NCCH.length);

// ---------------------------------------------------------------- build
NCW.make(1600, 900);
const spyLog = [];
NCUI.read = (info) => spyLog.push({ read: info });
NCUI.open = (tab) => spyLog.push({ open: tab });
const origTp = NCW.teleport;
NCW.teleport = (x, z, yaw) => spyLog.push({ tp: [x, z, yaw] });
for (const fn of ['testDiesel', 'toggleBay', 'drillSiren', 'ackAll']) {
  const o = NR[fn];
  NR[fn] = function () { spyLog.push({ nr: fn, args: [...arguments] }); return o.apply(this, arguments); };
}

for (let i = 0; i < NCCH.length; i++) {
  const t0 = Date.now();
  NCW.buildChunk(i);
  console.log('chunk', i, NCCH[i].name, Date.now() - t0, 'ms');
}
if (NCW.chunkErr) console.log('CHUNK ERRORS', NCW.chunkErr);
try { ncMountPass(); console.log('mount pass ok'); } catch (e) { console.log('mount pass failed', e.message); }
try { NCPR.build(); console.log('props built', NCPR.list.length); } catch (e) { console.log('props failed', e.message); }

// ---------------------------------------------------------------- serialise
const geoms = [];
const geoIndex = new Map();
const bin = [];
let binLen = 0;
const pushArr = (ta) => {
  const buf = Buffer.from(ta.buffer, ta.byteOffset, ta.byteLength);
  const off = binLen;
  bin.push(buf);
  binLen += buf.length;
  const pad = (4 - (binLen % 4)) % 4;
  if (pad) { bin.push(Buffer.alloc(pad)); binLen += pad; }
  return [off, ta.length];
};
function exportGeom(g) {
  if (geoIndex.has(g)) return geoIndex.get(g);
  const pos = g.attributes.position;
  if (!pos) { geoIndex.set(g, -1); return -1; }
  const o = { count: pos.count };
  o.p = pushArr(Float32Array.from(pos.array.slice(0, pos.count * 3)));
  if (g.attributes.normal) o.n = pushArr(Float32Array.from(g.attributes.normal.array.slice(0, pos.count * 3)));
  if (g.attributes.uv) o.u = pushArr(Float32Array.from(g.attributes.uv.array.slice(0, pos.count * 2)));
  if (g.attributes.color) o.c = pushArr(Float32Array.from(g.attributes.color.array.slice(0, pos.count * 3)));
  if (g.index) o.i = pushArr(Uint32Array.from(g.index.array));
  geoms.push(o);
  geoIndex.set(g, geoms.length - 1);
  return geoms.length - 1;
}

const texNames = new Map();
let texCount = 0;
const NCTRev = new Map();
for (const k in NCT) NCTRev.set(NCT[k], k);
function exportTex(t) {
  if (!t) return null;
  if (texNames.has(t)) return texNames.get(t);
  let name;
  if (NCTRev.has(t)) name = 'nct_' + NCTRev.get(t);
  else name = 'tex_' + texCount++;
  const img = t.image;
  if (img && img.toBuffer) {
    fs.writeFileSync(path.join(OUT, 'tex', name + '.png'), img.toBuffer('image/png'));
  }
  const info = { name, rx: t.repeat ? t.repeat.x : 1, ry: t.repeat ? t.repeat.y : 1, wrap: t.wrapS === THREE.RepeatWrapping ? 1 : 0 };
  texNames.set(t, info);
  return info;
}
const mats = [];
const matIndex = new Map();
function exportMat(m) {
  if (Array.isArray(m)) m = m[0];
  if (matIndex.has(m)) return matIndex.get(m);
  const o = {
    type: m.type, color: m.color ? m.color.toArray() : [1, 1, 1], emissive: m.emissive ? m.emissive.toArray() : [0, 0, 0],
    map: exportTex(m.map), opacity: m.opacity, transparent: !!m.transparent, side: m.side, vc: !!m.vertexColors,
    alphaTest: m.alphaTest || 0, blending: m.blending, depthWrite: m.depthWrite !== false, fog: m.fog !== false,
  };
  mats.push(o);
  matIndex.set(m, mats.length - 1);
  return mats.length - 1;
}
const objId = new Map();
let nextId = 1;
function serialise(o) {
  const id = nextId++;
  objId.set(o, id);
  const n = { id, name: o.name || '', t: o.isMesh ? 'mesh' : o.isSprite ? 'sprite' : o.isGroup || o.type === 'Group' ? 'group' : o.isLight ? 'light' : o.type };
  n.p = [o.position.x, o.position.y, o.position.z];
  n.r = [o.rotation.x, o.rotation.y, o.rotation.z, o.rotation.order];
  n.s = [o.scale.x, o.scale.y, o.scale.z];
  n.v = o.visible !== false;
  if (o.isMesh) { n.g = exportGeom(o.geometry); n.m = exportMat(o.material); n.ro = o.renderOrder || 0; }
  if (o.isSprite) { n.m = exportMat(o.material); }
  n.ch = [];
  for (const c of o.children) { if (c === NCW.cam) continue; n.ch.push(serialise(c)); }
  return n;
}
const chunks = NCW.chunks.map((g) => serialise(g));
let props = null;
if (NCPR.grp) props = serialise(NCPR.grp);

const ref = (v) => {
  if (v && v.isObject3D) return { ref: objId.get(v) || -1 };
  if (Array.isArray(v)) return v.map(ref);
  if (v && typeof v === 'object') { const r = {}; for (const k in v) { const x = v[k]; if (typeof x === 'number' || typeof x === 'string' || typeof x === 'boolean') r[k] = x; else if (x && x.isObject3D) r[k] = { ref: objId.get(x) || -1 }; } return r; }
  return v;
};
const anims = NCW.anim.map((a) => { const r = {}; for (const k in a) { const x = a[k]; if (typeof x === 'function') continue; r[k] = ref(x); } return r; });

const ints = NCW.ints.map((it) => {
  const o = { x: it.x, y: it.y, z: it.z, r: it.r, label: it.label, kind: it.kind || '', face: it.face, shuttle: !!it.shuttle, box: it.box || null, reach: it.reach || null };
  spyLog.length = 0;
  let src = '';
  try { src = String(it.fn).slice(0, 160); it.fn(); } catch (e) {}
  o.src = src;
  o.act = spyLog.slice();
  return o;
});
const infos = {};
for (const it of ints) for (const a of it.act) if (a.read) { infos[a.read.title] = a.read; }
for (const k in NCINFO) infos[NCINFO[k].title] = NCINFO[k];
const scr = NCW.scr.map((s) => ({ kind: s.kind, arg: s.arg, px: s.px, pz: s.pz, w: s.w, h: s.h, mid: objId.get(s.m) || -1, pw: s.m ? s.m.geometry.parameters.width : 1, ph: s.m ? s.m.geometry.parameters.height : 1 }));
const plns = NCW.plns.map((p) => ({ w: p.w, h: p.h, x: p.x, y: p.y, z: p.z, ry: p.ry, k: p.k, mid: objId.get(p.m) || -1 }));
const R = (o) => (o && objId.has(o) ? objId.get(o) : -1);
const alm = NCALM.list.map((B) => ({ g: R(B.g), rot: R(B.rot), dome: R(B.dome), bulb: R(B.rot.children[0]), beams: B.beams.map(R), halo: R(B.halo), s: B.s, ph: B.ph }));
const turbs = (NCW.turbs || []).map(R);
const puffs = (NCW.puffs || []).map((pf) => ({ tw: pf.tw, tx: pf.T.x, tz: pf.T.z, sp: pf.sp.map((q) => ({ s: R(q.s), ph: q.ph })) }));
const cr = NCW.crane ? { g: R(NCW.crane.g), tr: R(NCW.crane.g.children[1]), ch: R(NCW.crane.g.children[2]), hk: R(NCW.crane.g.children[3]) } : null;
const extra = { crane: cr, alm, turbs, puffs, poolSurf: R(NCW.poolSurf), sock: R(NCW.sock), clouds: (NCW.clouds || []).map(R) };
const out = {
  extra, geoms, mats, chunks, props, anims,
  col: NCW.col, cir: NCW.cir, floors: NCW.floors, shells: NCW.shells || [], zones: NCW.zones, ints, infos, scr, plns,
  lamps: typeof NC_LAMPS !== 'undefined' ? NC_LAMPS : [], planeSpot: NCW.planeSpot || null,
  towers: typeof NC_TOWERS !== 'undefined' ? NC_TOWERS : [],
  propList: NCPR.list.map((p) => ({ kind: p.kind, x: p.x, z: p.z, y: p.y, ry: p.ry, r: p.r, ci: p.ci, mid: p.mesh ? (objId.get(p.mesh) || -1) : -1, mass: p.mass, h: p.h, hr: p.hr, name: p.name })),
};
fs.writeFileSync(path.join(OUT, 'campus.json'), JSON.stringify(out));
fs.writeFileSync(path.join(OUT, 'campus.bin'), Buffer.concat(bin));
console.log('geoms', geoms.length, 'mats', mats.length, 'ints', ints.length, 'scr', scr.length, 'anims', anims.length, 'col', NCW.col.length, 'bin MB', (binLen / 1e6).toFixed(2));
