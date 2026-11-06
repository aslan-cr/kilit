// Oyuncuyla aynı girdi arayüzünü (step input) kullanan açgözlü bot. Denge testi ve ?autoplay için.
// Strateji: en yakın ışık böceğine (az mermi varsa mermi/silaha) BFS ile yürür, insan gibi arada kırpar,
// önünde yakın bir gölge varsa ve nişan uygunsa ateş eder.
import { bfs, hasLine, weaponDef } from "./sim.js";

export function makeBot(g, opts = {}) {
  const rand = opts.rand || Math.random;
  const st = { blinkIn: 2 + rand() * 3, blinkFor: 0 };

  return function botInput(dt) {
    const S = g.S;
    const input = { fwd: 0, str: 0, turn: 0, yaw: 0, eyes: false, fire: false, switchWeapon: false };

    // İnsan gibi kırpma (zorunlu kırpmayı beklemeden)
    if (st.blinkFor > 0) { st.blinkFor -= dt; input.eyes = true; }
    else { st.blinkIn -= dt; if (st.blinkIn <= 0) { st.blinkFor = 0.25 + rand() * 0.15; st.blinkIn = 3 + rand() * 3; } }

    // Hedef seç
    const targets = [];
    for (const o of g.flies) if (!o.taken) targets.push(o);
    if (g.shells < 3) for (const o of g.boxes) if (!o.taken) targets.push(o);
    for (const o of g.gunItems) if (!o.taken) targets.push(o);
    const dist = bfs(g.map, S, g.px | 0, g.py | 0);
    let tgt = null, bd = 1e9;
    for (const o of targets) {
      const d = dist[(o.y | 0) * S + (o.x | 0)];
      const w = g.shells < 3 && g.boxes.includes(o) ? d * 0.6 : d;
      if (d >= 0 && w < bd) { bd = w; tgt = o; }
    }

    // Ateş: önde, yakın, görüş çizgisi açık
    let aimYaw = null;
    const W = weaponDef(g);
    let nearest = null, nd = 1e9;
    for (const e of g.enemies) {
      if (!e.alive) continue;
      const d = Math.hypot(e.x - g.px, e.y - g.py);
      if (d < nd && hasLine(g, g.px, g.py, e.x, e.y)) { nd = d; nearest = e; }
    }
    if (nearest && nd < Math.min(W.range, 5) && g.shells >= W.shells) {
      aimYaw = Math.atan2(nearest.y - g.py, nearest.x - g.px);
      const diff = Math.atan2(Math.sin(aimYaw - g.yaw), Math.cos(aimYaw - g.yaw));
      if (Math.abs(diff) < 0.06 && g.cooldown <= 0) input.fire = true;
    }
    // Mevcut silah yetersizse (mermisi yetmiyor) başkasına geç
    if (g.shells < W.shells && g.owned.length > 1 && g.shells > 0) input.switchWeapon = true;

    // Yürüme yönü
    let want = null;
    if (aimYaw !== null) want = aimYaw;
    else if (tgt) {
      const cx = g.px | 0, cy = g.py | 0;
      if ((tgt.x | 0) === cx && (tgt.y | 0) === cy) want = Math.atan2(tgt.y - g.py, tgt.x - g.px);
      else {
        const toT = bfs(g.map, S, tgt.x | 0, tgt.y | 0);       // hedeften uzaklık: azalan komşuya yürü
        let best = toT[cy * S + cx], bx = cx, by = cy;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nx = cx + dx, ny = cy + dy, nd2 = toT[ny * S + nx];
          if (nd2 >= 0 && !g.map[ny * S + nx] && nd2 < best) { best = nd2; bx = nx; by = ny; }
        }
        want = Math.atan2(by + 0.5 - g.py, bx + 0.5 - g.px);
      }
    }
    if (want !== null) {
      const diff = Math.atan2(Math.sin(want - g.yaw), Math.cos(want - g.yaw));
      const maxTurn = 7 * dt;
      input.yaw = Math.max(-maxTurn, Math.min(maxTurn, diff));
      if (aimYaw === null && Math.abs(diff) < 0.9) input.fwd = 1;
    }
    return input;
  };
}
