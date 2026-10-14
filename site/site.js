// Shared behaviour for the fitgrid website: theme toggle, mobile menu,
// copy buttons, tabs and feature clips. Every page works without it.
(function () {
  var root = document.documentElement;

  // ---------- Theme ----------
  function store(value) {
    try { localStorage.setItem('fitgrid-theme', value); } catch (e) { /* private mode */ }
  }
  function effective() {
    var t = root.getAttribute('data-theme');
    if (t) return t;
    return window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  document.querySelectorAll('.theme-toggle').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var next = effective() === 'dark' ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      store(next);
      btn.setAttribute('aria-label', next === 'dark' ? 'Switch to light theme' : 'Switch to dark theme');
    });
    btn.setAttribute('aria-label', effective() === 'dark' ? 'Switch to light theme' : 'Switch to dark theme');
  });

  // ---------- Nav ----------
  var nav = document.querySelector('.site-nav');
  if (nav) {
    var onScroll = function () { nav.classList.toggle('scrolled', window.scrollY > 4); };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    var menu = nav.querySelector('.nav-menu');
    if (menu) {
      menu.addEventListener('click', function () {
        var open = !nav.classList.contains('open');
        nav.classList.toggle('open', open);
        menu.setAttribute('aria-expanded', String(open));
      });
      nav.querySelectorAll('.nav-links a').forEach(function (a) {
        a.addEventListener('click', function () {
          nav.classList.remove('open');
          menu.setAttribute('aria-expanded', 'false');
        });
      });
    }
  }

  // ---------- Copy ----------
  function copy(text, button, label) {
    var done = function () {
      button.classList.add('done');
      if (label) button.textContent = 'Copied';
      setTimeout(function () {
        button.classList.remove('done');
        if (label) button.textContent = label;
      }, 1500);
    };
    if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, function () {});
  }
  document.querySelectorAll('[data-copy]').forEach(function (button) {
    button.addEventListener('click', function () { copy(button.getAttribute('data-copy'), button); });
  });
  // Pages that add their own copy buttons (the docs page) are left alone.
  document.querySelectorAll('pre').forEach(function (pre) {
    if (pre.querySelector('button.copy')) return;
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'copy';
    button.textContent = 'Copy';
    button.addEventListener('click', function () {
      copy((pre.querySelector('code') || pre).innerText, button, 'Copy');
    });
    pre.appendChild(button);
  });

  // ---------- Tabs ----------
  document.querySelectorAll('.tabs').forEach(function (tabs) {
    var list = tabs.querySelectorAll('[role="tab"]');
    function select(tab) {
      list.forEach(function (t) {
        var on = t === tab;
        t.setAttribute('aria-selected', String(on));
        t.tabIndex = on ? 0 : -1;
        var panel = document.getElementById(t.getAttribute('aria-controls'));
        if (panel) panel.hidden = !on;
      });
    }
    list.forEach(function (tab, i) {
      tab.addEventListener('click', function () { select(tab); });
      tab.addEventListener('keydown', function (e) {
        var step = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
        if (!step) return;
        var next = list[(i + step + list.length) % list.length];
        select(next);
        next.focus();
      });
    });
  });
  // ---------- Clips ----------
  // Each clip plays only while it is on screen, and not at all for people who
  // ask for less motion: they get the poster and can open a clip to play it.
  var clips = document.querySelectorAll('video.clip');
  var still = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (clips.length && !still && 'IntersectionObserver' in window) {
    var seen = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        var v = entry.target;
        if (entry.isIntersecting) {
          v.preload = 'auto';
          var p = v.play();
          if (p && p.catch) p.catch(function () { /* autoplay refused: the poster stays */ });
        } else {
          v.pause();
        }
      });
    }, { threshold: 0.35 });
    clips.forEach(function (v) { seen.observe(v); });
  }

  // A clip in a card is small; clicking it plays it large, with controls.
  var shots = document.querySelectorAll('button.shot');
  if (shots.length && typeof HTMLDialogElement === 'function') {
    var dialog = document.createElement('dialog');
    dialog.className = 'clip-dialog';
    dialog.innerHTML = '<video controls playsinline loop muted></video>' +
      '<form method="dialog"><span></span><button type="submit">Close</button></form>';
    document.body.appendChild(dialog);
    var big = dialog.querySelector('video');
    var caption = dialog.querySelector('span');
    shots.forEach(function (shot) {
      shot.addEventListener('click', function () {
        var small = shot.querySelector('video');
        big.src = small.currentSrc || small.src;
        big.poster = small.poster;
        big.setAttribute('aria-label', small.getAttribute('aria-label'));
        caption.textContent = small.getAttribute('aria-label');
        dialog.showModal();
        var p = big.play();
        if (p && p.catch) p.catch(function () {});
      });
    });
    dialog.addEventListener('click', function (e) { if (e.target === dialog) dialog.close(); });
    dialog.addEventListener('close', function () { big.pause(); big.removeAttribute('src'); big.load(); });
  }
})();
