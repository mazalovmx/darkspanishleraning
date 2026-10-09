// Adds scattered resource sites to game/content/world/province.json. Deterministic:
// rerunning replaces the sites whose id starts with "wild_". Usage: node tools/scatter_sites.js
const fs = require("fs");
const file = __dirname + "/../game/content/world/province.json";
const map = JSON.parse(fs.readFileSync(file, "utf8"));
const treasures = JSON.parse(fs.readFileSync(__dirname + "/../game/content/world/treasures.json", "utf8")).treasures;
const [width, height] = map.size;
let seed = 20261008;
const random = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;
const terrain = (x, y) => map.legend[map.rows[y][x]];
// Cells a hero can reach from the first start without crossing water or mountains.
const reached = new Set([map.start.join()]);
for (const queue = [map.start]; queue.length;) {
  const [x, y] = queue.shift();
  for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    const nx = x + dx, ny = y + dy;
    if (nx < 0 || ny < 0 || nx >= width || ny >= height || reached.has(nx + "," + ny)) continue;
    if (["water", "mountain"].includes(terrain(nx, ny))) continue;
    reached.add(nx + "," + ny);
    queue.push([nx, ny]);
  }
}
map.resource_sites = map.resource_sites.filter(site => !site.id.startsWith("wild_"));
const gates = (map.gates || []).map(gate => gate.position || gate.cell || [-99, -99]);
const taken = [...map.locations, ...map.resource_sites, ...treasures].map(entry => entry.position).concat(gates);
const far = (x, y, gap) => taken.every(p => Math.max(Math.abs(p[0] - x), Math.abs(p[1] - y)) >= gap);
// resource, daily income, guards (none = free to claim)
const kinds = [
  ["wood", 1, null], ["ore", 1, null], ["wood", 2, [{type: "wolves", count: 8}]],
  ["ore", 2, [{type: "boars", count: 6}]], ["gold", 15, [{type: "wolves", count: 12}]],
  ["gold", 25, [{type: "bandits", count: 10}, {type: "thief", count: 4}]],
  ["wood", 3, [{type: "boars", count: 10}, {type: "wolves", count: 6}]],
  ["ore", 3, [{type: "bandits", count: 12}]], ["gold", 40, [{type: "bandits", count: 16}, {type: "wolves", count: 8}]]];
const starts = Object.values(map.hero_starts);
let made = 0;
const place = (x, y) => {
  if (!reached.has(x + "," + y) || !["grass", "field", "forest", "ruins", "snow"].includes(terrain(x, y)) || !far(x, y, 4)) return false;
  // Near a hero start only the easy kinds appear.
  const near = starts.some(p => Math.max(Math.abs(p[0] - x), Math.abs(p[1] - y)) <= 14);
  const kind = kinds[Math.floor(random() * (near ? 4 : kinds.length))];
  made += 1;
  const site = {id: "wild_" + String(made).padStart(2, "0"), resource: kind[0], position: [x, y], daily_income: kind[1], guarded: kind[2] !== null};
  if (kind[2]) site.guards = kind[2];
  map.resource_sites.push(site);
  taken.push([x, y]);
  return true;
};
// Three within a short walk of each start, then the rest across the province.
for (const start of starts)
  for (let count = 0, tries = 0; count < 3 && tries < 2000; tries++)
    if (place(start[0] + Math.floor(random() * 19) - 9, start[1] + Math.floor(random() * 19) - 9)) count += 1;
for (let tries = 0; made < 45 && tries < 20000; tries++)
  place(Math.floor(random() * width), Math.floor(random() * height));
fs.writeFileSync(file, JSON.stringify(map, null, 2) + "\n");
console.log("sites:", map.resource_sites.length, "new:", made);
