/* Touch POS database link: stores all data in the SQLite database kept by touchpos-helper.ps1.
   Provides window.posStore (getRaw, setRaw, clear, pictureUrl), which the app uses instead of browser storage.
   Customer pictures are only sent to the database when they change. */
(function () {
  var BASE = 'http://127.0.0.1:47615', key = '';
  try { key = new URLSearchParams(location.search).get('k') || ''; } catch (e) { }
  try { if (key) localStorage.setItem('tpk', key); else key = localStorage.getItem('tpk') || ''; } catch (e) { }

  function call(method, path, body) {
    var x = new XMLHttpRequest();
    x.open(method, BASE + path + (path.indexOf('?') < 0 ? '?' : '&') + 'k=' + encodeURIComponent(key), false);
    if (body != null) x.setRequestHeader('Content-Type', 'text/plain;charset=UTF-8');
    x.send(body == null ? null : body);
    return x;
  }
  function used() { try { return localStorage.getItem('tpdb') === '1'; } catch (e) { return false; } }

  var up = false;
  try { var p = call('GET', '/ping'); up = p.status === 200 && p.responseText.indexOf('touchpos') > -1; } catch (e) { }
  if (up) { try { up = call('GET', '/status').status === 200; } catch (e) { up = false; } }
  if (!up) {
    if (used()) window.TPDB_DOWN = true;
    return;
  }

  var photos = {};
  function fail(what, x) {
    var msg = 'Could not save ' + what + ' to the database' + (x && x.responseText ? ': ' + x.responseText : '');
    window.TPDB_ERR = msg;
    try { if (window.toast) toast(msg); } catch (e) { }
    throw new Error(msg);
  }
  var names = { p: 'products', c: 'customers', s: 'sales', t: 'settings', y: 'payment links', v: 'devices', u: 'staff', l: 'layouts' };

  window.posStore = {
    getRaw: function (k) {
      var x = call('GET', '/get?n=' + k);
      if (x.status === 404) return null;
      if (x.status !== 200) throw new Error('Database read failed: ' + x.responseText);
      if (k === 'c') {
        try { JSON.parse(x.responseText).forEach(function (c) { if (c && c.id) photos[c.id] = c.photo || ''; }); } catch (e) { }
      }
      return x.responseText;
    },
    setRaw: function (k, js) {
      var body = js, list = null;
      if (k === 'c') {
        list = JSON.parse(js) || [];
        body = JSON.stringify(list.map(function (c) {
          if (c && c.id && c.photo && photos[c.id] === c.photo) { var o = Object.assign({}, c); o.photo = 'db:keep'; return o; }
          return c;
        }));
      }
      var x;
      try { x = call('POST', '/set?n=' + k, body); } catch (e) { fail(names[k] || k, null); }
      if (x.status !== 200) fail(names[k] || k, x);
      if (list) { photos = {}; list.forEach(function (c) { if (c && c.id) photos[c.id] = c.photo || ''; }); }
    },
    clear: function () { call('POST', '/clear', ''); photos = {}; },
    pictureUrl: function (u) { return BASE + '/fetch?url=' + encodeURIComponent(u) + '&k=' + encodeURIComponent(key); },
    status: function () { try { return JSON.parse(call('GET', '/status').responseText); } catch (e) { return null; } }
  };

  // First run with the database: move anything already kept in browser storage into it.
  try {
    var st = window.posStore.status();
    if (st && !st.kv && !st.customers) {
      ['p', 'c', 's', 't', 'y', 'v', 'u', 'l'].forEach(function (k) {
        var v = localStorage.getItem(k);
        if (v != null) window.posStore.setRaw(k, v);
      });
    }
    localStorage.setItem('tpdb', '1');
  } catch (e) { }
})();
