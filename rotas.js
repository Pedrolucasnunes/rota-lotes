// Rotas internas do condomínio: monta um grafo com as ruas salvas e calcula o menor caminho.
// Usado pelo painel (index.html) e pela página do entregador (entregador.html).
(function () {
  var R = 6371000, toR = Math.PI / 180;

  function dist(a, b) {
    var dLat = (b[0] - a[0]) * toR, dLng = (b[1] - a[1]) * toR;
    var h = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(a[0] * toR) * Math.cos(b[0] * toR) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return 2 * R * Math.asin(Math.sqrt(h));
  }
  function key(p) { return (+p[0]).toFixed(6) + ',' + (+p[1]).toFixed(6); }

  // Projeta o ponto p no segmento a-b (aproximação plana, ótima para distâncias de condomínio)
  function project(p, a, b) {
    var k = Math.cos(a[0] * toR);
    var ax = a[1] * k, ay = a[0], bx = b[1] * k, by = b[0], px = p[1] * k, py = p[0];
    var dx = bx - ax, dy = by - ay, len2 = dx * dx + dy * dy;
    var t = len2 ? ((px - ax) * dx + (py - ay) * dy) / len2 : 0;
    t = Math.max(0, Math.min(1, t));
    var pt = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
    return { pt: pt, t: t, d: dist(p, pt) };
  }

  // ruas: lista de linhas, cada linha = [[lat,lng],[lat,lng],...]
  function buildGraph(ruas) {
    var lines = (ruas || []).filter(function (l) { return Array.isArray(l) && l.length >= 2; })
      .map(function (l) { return l.map(function (p) { return [+p[0], +p[1]]; }); });
    if (!lines.length) return null;

    // Liga pontas soltas a ruas próximas (até 10 m), para cruzamentos desenhados à mão
    var owners = {};
    lines.forEach(function (l, li) { l.forEach(function (p) { (owners[key(p)] = owners[key(p)] || []).push(li); }); });
    lines.forEach(function (l, li) {
      [0, l.length - 1].forEach(function (ei) {
        var p = l[ei], o = owners[key(p)] || [];
        if (o.some(function (x) { return x !== li; })) return;
        var best = null;
        lines.forEach(function (m, mi) {
          if (mi === li) return;
          for (var i = 0; i < m.length - 1; i++) {
            var pr = project(p, m[i], m[i + 1]);
            if (!best || pr.d < best.d) best = { d: pr.d, mi: mi, i: i, pt: pr.pt, t: pr.t };
          }
        });
        if (best && best.d <= 10) {
          var m = lines[best.mi], np;
          if (best.t <= 0.001) np = m[best.i];
          else if (best.t >= 0.999) np = m[best.i + 1];
          else { np = best.pt; m.splice(best.i + 1, 0, np); }
          l[ei] = np;
          (owners[key(np)] = owners[key(np)] || []).push(li, best.mi);
        }
      });
    });

    var nodes = {}, adj = {}, segs = [];
    lines.forEach(function (l) {
      for (var i = 0; i < l.length - 1; i++) {
        var a = l[i], b = l[i + 1], ka = key(a), kb = key(b);
        if (ka === kb) continue;
        var w = dist(a, b);
        nodes[ka] = a; nodes[kb] = b;
        (adj[ka] = adj[ka] || []).push([kb, w]);
        (adj[kb] = adj[kb] || []).push([ka, w]);
        segs.push([a, b]);
      }
    });
    return { nodes: nodes, adj: adj, segs: segs, lines: lines };
  }

  function nearest(g, p) {
    var best = null;
    g.segs.forEach(function (s) {
      var pr = project(p, s[0], s[1]);
      if (!best || pr.d < best.d) best = { d: pr.d, pt: pr.pt, a: s[0], b: s[1] };
    });
    return best;
  }

  // Menor caminho de "from" até "to" pelas ruas. Retorna { path, length, startGap, endGap } ou null.
  function route(g, from, to) {
    if (!g) return null;
    var s = nearest(g, from), e = nearest(g, to);
    if (!s || !e) return null;
    var S = '__S', E = '__E';
    var nodes = Object.assign({}, g.nodes); nodes[S] = s.pt; nodes[E] = e.pt;
    var extra = {};
    function link(x, y, w) { (extra[x] = extra[x] || []).push([y, w]); (extra[y] = extra[y] || []).push([x, w]); }
    link(S, key(s.a), dist(s.pt, s.a)); link(S, key(s.b), dist(s.pt, s.b));
    link(E, key(e.a), dist(e.pt, e.a)); link(E, key(e.b), dist(e.pt, e.b));
    if ((key(s.a) === key(e.a) && key(s.b) === key(e.b)) || (key(s.a) === key(e.b) && key(s.b) === key(e.a))) link(S, E, dist(s.pt, e.pt));

    var D = {}, prev = {}, done = {}, open = [S];
    D[S] = 0;
    while (open.length) {
      var bi = 0;
      for (var i = 1; i < open.length; i++) if (D[open[i]] < D[open[bi]]) bi = i;
      var u = open.splice(bi, 1)[0];
      if (done[u]) continue;
      done[u] = true;
      if (u === E) break;
      var nb = (g.adj[u] || []).concat(extra[u] || []);
      for (var j = 0; j < nb.length; j++) {
        var v = nb[j][0], nd = D[u] + nb[j][1];
        if (!done[v] && (D[v] === undefined || nd < D[v])) { D[v] = nd; prev[v] = u; open.push(v); }
      }
    }
    if (D[E] === undefined) return null;
    var path = [], k = E;
    while (k) { path.unshift(nodes[k]); k = prev[k]; }
    return { path: path, length: D[E], startGap: s.d, endGap: e.d };
  }

  // Onde o ponto p está em relação ao caminho: ponto mais próximo, quanto falta e a distância até o caminho
  function progress(path, p) {
    if (!path || path.length < 2) return null;
    var best = null;
    for (var i = 0; i < path.length - 1; i++) {
      var pr = project(p, path[i], path[i + 1]);
      if (!best || pr.d < best.d) best = { i: i, pt: pr.pt, d: pr.d };
    }
    var rem = dist(best.pt, path[best.i + 1]);
    for (var j = best.i + 1; j < path.length - 1; j++) rem += dist(path[j], path[j + 1]);
    return { pt: best.pt, gap: best.d, remaining: rem, index: best.i };
  }

  window.Rotas = { buildGraph: buildGraph, route: route, progress: progress, dist: dist, nearest: nearest, key: key };
})();
