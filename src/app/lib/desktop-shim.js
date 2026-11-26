/* Desktop shims: file saving without the web host, and a jsPDF-compatible layer built on pdf-lib (works offline). */
(function () {
  function dl(blob, name) {
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = name;
    document.body.appendChild(a); a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 4000);
  }
  if (!window.claude) {
    window.claude = { use: function () { return Promise.resolve({ save: function (o) { var b = o.data instanceof Blob ? o.data : new Blob([o.data]); dl(b, o.filename); return Promise.resolve(); } }); } };
  }
  var MM = 72 / 25.4, PH = 297 * MM;
  function Doc() { this.pages = [[]]; this.cur = 0; this.st = { font: 'normal', size: 10, text: [0, 0, 0], draw: [0, 0, 0], fill: [255, 255, 255] }; }
  function col(a) { if (a.length === 1) a = [a[0], a[0], a[0]]; return [a[0], a[1], a[2]]; }
  var P = Doc.prototype;
  P._o = function (o) { o.st = { font: this.st.font, size: this.st.size, text: this.st.text.slice(), draw: this.st.draw.slice(), fill: this.st.fill.slice() }; this.pages[this.cur].push(o); };
  P.setFont = function (f, s) { this.st.font = s || 'normal'; return this; };
  P.setFontSize = function (n) { this.st.size = n; return this; };
  P.setTextColor = function () { this.st.text = col([].slice.call(arguments)); return this; };
  P.setDrawColor = function () { this.st.draw = col([].slice.call(arguments)); return this; };
  P.setFillColor = function () { this.st.fill = col([].slice.call(arguments)); return this; };
  P.text = function (s, x, y, o) { this._o({ t: 'text', s: String(s), x: x, y: y, align: o && o.align }); return this; };
  P.rect = function (x, y, w, h, style) { this._o({ t: 'rect', x: x, y: y, w: w, h: h, fill: style === 'F' }); return this; };
  P.line = function (x1, y1, x2, y2) { this._o({ t: 'line', x1: x1, y1: y1, x2: x2, y2: y2 }); return this; };
  P.addImage = function (d, f, x, y, w, h) { this._o({ t: 'img', d: d, x: x, y: y, w: w, h: h }); return this; };
  P.addPage = function () { this.pages.push([]); this.cur = this.pages.length - 1; return this; };
  P.setPage = function (n) { this.cur = n - 1; return this; };
  P.getNumberOfPages = function () { return this.pages.length; };
  function bytes(d) { var b = atob(d.split(',')[1]), u = new Uint8Array(b.length); for (var i = 0; i < b.length; i++) u[i] = b.charCodeAt(i); return u; }
  P.output = async function () {
    var L = window.PDFLib, pdf = await L.PDFDocument.create();
    var fn = { normal: await pdf.embedFont(L.StandardFonts.Helvetica), bold: await pdf.embedFont(L.StandardFonts.HelveticaBold) };
    var cache = {}, rgb = function (c) { return L.rgb(c[0] / 255, c[1] / 255, c[2] / 255); };
    for (var p = 0; p < this.pages.length; p++) {
      var pg = pdf.addPage([210 * MM, 297 * MM]), ops = this.pages[p];
      for (var i = 0; i < ops.length; i++) {
        var o = ops[i], s = o.st;
        try {
          if (o.t === 'text') {
            var f = fn[s.font === 'bold' ? 'bold' : 'normal'], w = f.widthOfTextAtSize(o.s, s.size), x = o.x * MM;
            if (o.align === 'right') x -= w; else if (o.align === 'center') x -= w / 2;
            pg.drawText(o.s, { x: x, y: PH - o.y * MM, size: s.size, font: f, color: rgb(s.text) });
          } else if (o.t === 'rect') {
            var op = { x: o.x * MM, y: PH - (o.y + o.h) * MM, width: o.w * MM, height: o.h * MM };
            if (o.fill) op.color = rgb(s.fill); else { op.borderColor = rgb(s.draw); op.borderWidth = 0.6; }
            pg.drawRectangle(op);
          } else if (o.t === 'line') {
            pg.drawLine({ start: { x: o.x1 * MM, y: PH - o.y1 * MM }, end: { x: o.x2 * MM, y: PH - o.y2 * MM }, thickness: 0.6, color: rgb(s.draw) });
          } else if (o.t === 'img') {
            var im = cache[o.d];
            if (!im) { var u = bytes(o.d); im = cache[o.d] = /^data:image\/png/.test(o.d) ? await pdf.embedPng(u) : await pdf.embedJpg(u); }
            pg.drawImage(im, { x: o.x * MM, y: PH - (o.y + o.h) * MM, width: o.w * MM, height: o.h * MM });
          }
        } catch (e) {
          if (o.t === 'text') { try { pg.drawText(o.s.replace(/[^\x20-\x7e]/g, '?'), { x: o.x * MM, y: PH - o.y * MM, size: s.size, font: fn.normal }); } catch (x2) {} }
          else if (o.t === 'img') { /* skip unreadable image */ }
        }
      }
    }
    return new Blob([await pdf.save()], { type: 'application/pdf' });
  };
  P.save = function (name) { return this.output().then(function (b) { dl(b, name); }); };
  window.jspdf = { jsPDF: function () { return new Doc(); } };
})();
