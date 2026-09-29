// Builds site/docs.html from the package README, so the website's guide is
// always the README and never a second copy that drifts from it.
//
//   cd tool/docs && dart run bin/build_docs.dart
//
// The README's own "Contents" block becomes the sidebar; its groups are the
// sidebar's groups. Any `## ` section the Contents block doesn't list lands
// under "More". The build fails if an in-page link points at a heading that
// doesn't exist, which is also a check on the README itself.
import 'dart:convert';
import 'dart:io';

import 'package:markdown/markdown.dart' as md;

const _site = 'https://fitgrid-e734.vercel.app/';
const _rawScreenshots =
    'https://raw.githubusercontent.com/Amodh2022/fitgrid/main/screenshots/';
const _repo = 'https://github.com/Amodh2022/fitgrid';

void main(List<String> args) {
  final readmePath = args.isNotEmpty ? args[0] : '../../README.md';
  final outPath = args.length > 1 ? args[1] : '../../site/docs.html';
  final readme = File(readmePath).readAsStringSync();
  final version = _packageVersion(File(readmePath).parent);

  final parts = _split(readme);
  final groups = _parseContents(parts.contents);

  final ids = <String, int>{};
  final intro = _render(parts.intro, ids, dropTitle: true);
  final body = _render(parts.body, ids);

  // Sidebar: the Contents groups, each h2 with its h3s underneath.
  final listed = {for (final g in groups) ...g.ids};
  final extra = body.sections.where((s) => !listed.contains(s.id)).toList();
  if (extra.isNotEmpty) {
    groups.add(_Group('More', [for (final s in extra) s.id]));
  }
  final byId = {for (final s in body.sections) s.id: s};
  final nav = StringBuffer();
  for (final g in groups) {
    nav.writeln('<p class="group">${_esc(g.title)}</p><ul>');
    for (final id in g.ids) {
      final s = byId[id];
      if (s == null) {
        stderr.writeln('Contents links to #$id, but no "## " heading has it.');
        exit(1);
      }
      nav.write('<li><a href="#$id">${_esc(s.title)}</a>');
      if (s.children.isNotEmpty) {
        nav.write('<ul>');
        for (final c in s.children) {
          nav.write('<li><a href="#${c.id}">${_esc(c.title)}</a></li>');
        }
        nav.write('</ul>');
      }
      nav.writeln('</li>');
    }
    nav.writeln('</ul>');
  }

  // Every in-page link has to land somewhere.
  final html = '${intro.html}\n${body.html}';
  final broken = RegExp(r'href="#([^"]+)"')
      .allMatches(html)
      .map((m) => m[1]!)
      .where((id) => !ids.containsKey(id))
      .toSet();
  if (broken.isNotEmpty) {
    stderr.writeln('Links to headings that do not exist: ${broken.join(', ')}');
    exit(1);
  }

  File(outPath).writeAsStringSync(
    _page(intro: intro.html, body: body.html, nav: '$nav', version: version),
  );
  stdout.writeln(
    'Wrote $outPath: ${body.sections.length} sections, '
    '${groups.length} groups.',
  );
}

class _Parts {
  _Parts(this.intro, this.contents, this.body);
  final String intro, contents, body;
}

/// The README is: title and pitch, `---`, `## Contents`, `---`, the guide.
_Parts _split(String readme) {
  final lines = const LineSplitter().convert(readme);
  final contentsAt = lines.indexOf('## Contents');
  if (contentsAt < 0) {
    stderr.writeln('README has no "## Contents" heading.');
    exit(1);
  }
  final rule = lines.indexOf('---', contentsAt);
  String join(Iterable<String> l) => l.join('\n');
  var introEnd = contentsAt;
  while (introEnd > 0 &&
      (lines[introEnd - 1].trim().isEmpty || lines[introEnd - 1] == '---')) {
    introEnd--;
  }
  return _Parts(
    join(lines.sublist(0, introEnd)),
    join(lines.sublist(contentsAt + 1, rule)),
    join(lines.sublist(rule + 1)),
  );
}

class _Group {
  _Group(this.title, this.ids);
  final String title;
  final List<String> ids;
}

List<_Group> _parseContents(String contents) {
  final groups = <_Group>[];
  for (final line in const LineSplitter().convert(contents)) {
    final title = RegExp(r'^\*\*(.+)\*\*$').firstMatch(line.trim());
    if (title != null) {
      groups.add(_Group(title[1]!, []));
      continue;
    }
    for (final m in RegExp(r'\]\(#([^)]+)\)').allMatches(line)) {
      groups.last.ids.add(m[1]!);
    }
  }
  return groups;
}

class _Heading {
  _Heading(this.id, this.title);
  final String id, title;
  final children = <_Heading>[];
}

class _Rendered {
  _Rendered(this.html, this.sections);
  final String html;
  final List<_Heading> sections;
}

_Rendered _render(
  String source,
  Map<String, int> ids, {
  bool dropTitle = false,
}) {
  final doc = md.Document(extensionSet: md.ExtensionSet.gitHubWeb);
  var nodes = doc.parseLines(const LineSplitter().convert(source));
  if (dropTitle) {
    nodes = nodes.where((n) => !(n is md.Element && n.tag == 'h1')).toList();
  }

  final sections = <_Heading>[];
  final out = StringBuffer();
  for (final node in nodes) {
    if (node is md.Element && (node.tag == 'h2' || node.tag == 'h3')) {
      final title = node.textContent;
      final id = _slug(title, ids);
      node.attributes['id'] = id;
      final h = _Heading(id, title);
      if (node.tag == 'h2') {
        sections.add(h);
      } else if (sections.isNotEmpty) {
        sections.last.children.add(h);
      }
      // A hover anchor, the way GitHub does it.
      node.children!.add(
        md.Element('a', [md.Text('#')])
          ..attributes['class'] = 'anchor'
          ..attributes['href'] = '#$id'
          ..attributes['aria-label'] = 'Link to this section',
      );
    }
    _rewriteUrls(node);
    var html = md.renderToHtml([node]);
    // Wide tables scroll inside themselves rather than widening the page.
    if (node is md.Element && node.tag == 'table') {
      html = '<div class="table">$html</div>';
    }
    out.writeln(html);
  }
  return _Rendered('$out', sections);
}

/// Screenshots and links to the website become relative, so the page works
/// on a preview deploy and when opened from disk.
void _rewriteUrls(md.Node node) {
  if (node is! md.Element) return;
  for (final attr in ['src', 'href']) {
    final url = node.attributes[attr];
    if (url == null) continue;
    if (url.startsWith(_rawScreenshots)) {
      node.attributes[attr] =
          'screenshots/${url.substring(_rawScreenshots.length)}';
    } else if (url.startsWith(_site)) {
      final rest = url.substring(_site.length);
      node.attributes[attr] = rest.isEmpty ? './' : rest;
    }
  }
  if (node.tag == 'img') node.attributes['loading'] = 'lazy';
  node.children?.forEach(_rewriteUrls);
}

/// GitHub's heading ids, so the README's `#anchors` work unchanged.
String _slug(String title, Map<String, int> seen) {
  final base = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s_-]', unicode: true), '')
      .trim()
      .replaceAll(RegExp(r'\s'), '-');
  final n = seen[base];
  seen[base] = (n ?? -1) + 1;
  final id = n == null ? base : '$base-${n + 1}';
  seen.putIfAbsent(id, () => 0);
  return id;
}

String _packageVersion(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return '';
  final m = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  return m?[1] ?? '';
}

String _esc(String s) => const HtmlEscape().convert(s);

String _page({
  required String intro,
  required String body,
  required String nav,
  required String version,
}) =>
    '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>fitgrid docs — the complete guide</title>
  <meta name="description" content="The complete guide to fitgrid, a fast Flutter data table and data grid: columns and widths, theming, sorting, filters, editing, ranges, grouping, detail rows, pagination, export, pivots and the full API.">
  <link rel="canonical" href="${_site}docs.html">
  <meta property="og:title" content="fitgrid docs — the complete guide">
  <meta property="og:description" content="Every feature of fitgrid, the fast Flutter data grid, with examples.">
  <meta property="og:image" content="${_site}screenshots/overview.png">
  <meta property="og:type" content="website">
  <meta name="twitter:card" content="summary_large_image">
  <!-- Generated from README.md by tool/docs/bin/build_docs.dart. Edit the README, not this file. -->
  <meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#070b14" media="(prefers-color-scheme: dark)">
  <script>document.documentElement.className='js';try{var t=localStorage.getItem('fitgrid-theme');if(t)document.documentElement.setAttribute('data-theme',t)}catch(e){}</script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap">
  <link rel="stylesheet" href="style.css">
  <style>
    /* Docs layout. Colours, type, nav, code and tables come from style.css. */
    html { scroll-padding-top:80px; }
    .site-nav .brand .sub { font-weight:500; color:var(--muted); }
    #menu { display:none; }

    .layout { display:grid; grid-template-columns:280px minmax(0,1fr); max-width:1280px; margin:0 auto; }
    aside { position:sticky; top:61px; height:calc(100vh - 61px); overflow-y:auto; padding:24px 16px 48px 24px; border-right:1px solid var(--line); }
    aside input { width:100%; height:38px; padding:0 12px; border:1px solid var(--line); border-radius:10px; background:var(--bg-soft); color:var(--fg); font:inherit; font-size:.9rem; }
    aside input:focus { outline:2px solid var(--accent); outline-offset:-1px; background:var(--card); }
    aside p.group { margin:26px 0 8px; padding-left:12px; font-size:.72rem; font-weight:700; letter-spacing:.08em; text-transform:uppercase; color:var(--muted); }
    aside ul { list-style:none; margin:0; padding:0; }
    aside a { display:block; padding:5px 12px; border-radius:8px; color:var(--fg); text-decoration:none; font-size:.9rem; line-height:1.4; border-left:2px solid transparent; }
    aside a:hover { background:var(--bg-soft); color:var(--fg); }
    aside ul ul { display:none; margin:2px 0 6px 12px; border-left:1px solid var(--line); }
    aside ul ul a { font-size:.84rem; color:var(--muted); padding:4px 12px; border-radius:0 8px 8px 0; margin-left:-1px; }
    aside li.open > ul, aside.searching ul ul { display:block; }
    aside a.active { background:var(--accent-soft); color:var(--accent-fg); font-weight:600; }
    aside ul ul a.active { border-left-color:var(--accent); background:none; }
    aside .none { display:none; color:var(--muted); font-size:.9rem; margin-top:16px; padding-left:12px; }

    article { min-width:0; padding:48px 56px 96px; max-width:920px; }
    article h1 { font-size:clamp(2.2rem, 1.6rem + 2vw, 3rem); font-weight:800; letter-spacing:-.035em; margin:0 0 16px; }
    article h2 { font-size:1.75rem; margin:80px 0 14px; padding-top:28px; border-top:1px solid var(--line); }
    article h3 { font-size:1.2rem; margin:40px 0 10px; }
    article h2, article h3 { position:relative; }
    article p, article li { color:var(--fg); }
    article ul, article ol { padding-left:22px; }
    article li { margin-bottom:6px; }
    .anchor { margin-left:8px; color:var(--muted); text-decoration:none; opacity:0; transition:opacity .15s; }
    h2:hover .anchor, h3:hover .anchor, .anchor:focus { opacity:1; }
    .intro { font-size:1.06rem; }
    .intro > p:first-of-type { font-size:1.2rem; color:var(--muted); }
    .intro img { border:1px solid var(--line); border-radius:var(--radius-lg); box-shadow:var(--shadow-lg); margin:24px 0; }
    .buttons { display:flex; flex-wrap:wrap; gap:10px; margin:24px 0 8px; }
    .buttons a { display:inline-flex; align-items:center; height:40px; padding:0 16px; border-radius:10px; font-weight:600; font-size:.92rem; text-decoration:none; color:#fff; background:linear-gradient(135deg, #2563eb, #6d4aea); box-shadow:0 6px 20px var(--glow); }
    .buttons a:hover { color:#fff; }
    .buttons a.secondary { color:var(--fg); background:var(--card); border:1px solid var(--line); box-shadow:none; }
    .buttons a.secondary:hover { background:var(--card-hover); }
    article img { border-radius:var(--radius); border:1px solid var(--line); }
    article pre { margin:18px 0; }
    pre code.hljs { background:none; padding:0; }
    .table { margin:18px 0; overflow-x:auto; border:1px solid var(--line); border-radius:var(--radius); background:var(--card); }
    .table table { font-size:.9rem; }
    blockquote { margin:18px 0; padding:12px 18px; border:1px solid color-mix(in srgb, var(--accent) 30%, var(--line)); border-left:3px solid var(--accent); background:var(--accent-soft); border-radius:0 var(--radius) var(--radius) 0; }
    blockquote p:last-child { margin-bottom:0; }
    hr { border:0; border-top:1px solid var(--line); margin:40px 0; }
    article footer { color:var(--muted); margin-top:80px; font-size:.9rem; border-top:1px solid var(--line); padding-top:20px; }

    @media (max-width:900px) {
      #menu { display:inline-flex; align-items:center; height:36px; padding:0 12px; border:1px solid var(--line); border-radius:9px; background:var(--card); color:var(--fg); font:500 .88rem/1 var(--font); cursor:pointer; }
      .layout { display:block; }
      aside { display:none; position:fixed; top:61px; left:0; right:0; bottom:0; height:auto; z-index:19; background:var(--bg); border-right:0; padding:20px 16px 48px; }
      body.nav-open aside { display:block; }
      body.nav-open { overflow:hidden; }
      article { padding:28px 16px 72px; }
      article h2 { margin-top:56px; }
      .anchor { display:none; }
    }
  </style>
</head>
<body>
<header class="site-nav always-line">
  <div class="bar" style="padding:0 16px;max-width:1280px;margin:0 auto">
    <a class="brand" href="./" aria-label="fitgrid home">
      <span class="logo" aria-hidden="true"><svg viewBox="0 0 16 16" fill="none" stroke="#fff" stroke-width="1.6"><rect x="1.5" y="2.5" width="13" height="11" rx="2"/><path d="M1.5 6.5h13M6 6.5v7"/></svg></span>
      fitgrid <span class="sub">docs</span>
    </a>
    ${version.isEmpty ? '' : '<a class="pill" href="https://pub.dev/packages/fitgrid_table">v$version</a>'}
    <nav class="nav-links" aria-label="Main">
      <a href="docs.html" aria-current="page">Docs</a>
      <a href="demo/">Demo</a>
      <a href="choosing-a-flutter-data-table.html">Compare</a>
      <a href="https://pub.dev/documentation/fitgrid_table/latest/">API</a>
      <a href="https://pub.dev/packages/fitgrid_table">pub.dev</a>
    </nav>
    <div class="nav-tools">
      <button id="menu" type="button" aria-expanded="false" aria-controls="sidebar">Contents</button>
      <a class="icon-btn gh" href="$_repo" aria-label="fitgrid on GitHub"><svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg></a>
      <button class="icon-btn theme-toggle" type="button" aria-label="Toggle theme"><svg class="moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12.8A9 9 0 1111.2 3a7 7 0 009.8 9.8z"/></svg><svg class="sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg></button>
      <button class="icon-btn nav-menu" type="button" aria-label="Menu" aria-expanded="false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16"/></svg></button>
    </div>
  </div>
</header>
<div class="layout">
  <aside id="sidebar" aria-label="Contents">
    <input type="search" id="filter" placeholder="Filter sections…" aria-label="Filter sections">
    $nav
    <p class="none">No section matches.</p>
  </aside>
  <article>
    <h1>fitgrid</h1>
    <div class="intro">
$intro
    </div>
    <p class="buttons">
      <a href="#install">Install</a>
      <a class="secondary" href="#your-first-grid">Your first grid</a>
      <a class="secondary" href="#column-reference">Column reference</a>
    </p>
$body
    <footer>
      This page is built from the package <a href="$_repo#readme">README</a>.
      Found something wrong? <a href="$_repo/edit/main/README.md">Edit it on GitHub</a>
      or <a href="$_repo/issues">open an issue</a>. fitgrid_table is free and open source under the MIT license.
    </footer>
  </article>
</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/dart.min.js"></script>
<script src="site.js" defer></script>
<script>
  // Code: highlight, and a copy button on each block.
  document.querySelectorAll('pre > code').forEach(function (code) {
    if (window.hljs && /language-/.test(code.className)) hljs.highlightElement(code);
    var btn = document.createElement('button');
    btn.className = 'copy';
    btn.type = 'button';
    btn.textContent = 'Copy';
    btn.addEventListener('click', function () {
      navigator.clipboard.writeText(code.innerText).then(function () {
        btn.textContent = 'Copied';
        setTimeout(function () { btn.textContent = 'Copy'; }, 1500);
      });
    });
    code.parentNode.appendChild(btn);
  });

  // Sidebar: highlight the section being read, and open its sub-sections.
  var aside = document.getElementById('sidebar');
  var links = {};
  aside.querySelectorAll('a').forEach(function (a) { links[a.hash.slice(1)] = a; });
  var headings = Array.prototype.filter.call(
    document.querySelectorAll('article h2[id], article h3[id]'),
    function (h) { return links[h.id]; });
  var current = null;
  function track() {
    var top = null;
    for (var i = 0; i < headings.length; i++) {
      if (headings[i].getBoundingClientRect().top > 96) break;
      top = headings[i];
    }
    var a = top && links[top.id];
    if (a === current) return;
    aside.querySelectorAll('.active, .open').forEach(function (el) { el.classList.remove('active', 'open'); });
    current = a;
    if (!a) return;
    a.classList.add('active');
    for (var li = a.parentNode; li && li !== aside; li = li.parentNode) {
      if (li.tagName === 'LI') li.classList.add('open');
    }
    if (!document.body.classList.contains('nav-open')) {
      var r = a.getBoundingClientRect(), box = aside.getBoundingClientRect();
      if (r.top < box.top || r.bottom > box.bottom) a.scrollIntoView({ block: 'center' });
    }
  }
  var ticking = false;
  addEventListener('scroll', function () {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () { ticking = false; track(); });
  }, { passive: true });
  track();

  // Sidebar filter.
  var filter = document.getElementById('filter');
  filter.addEventListener('input', function () {
    var q = filter.value.trim().toLowerCase();
    aside.classList.toggle('searching', q !== '');
    var any = false;
    aside.querySelectorAll('ul').forEach(function (ul) {
      if (ul.parentNode !== aside) return;
      var shown = 0;
      ul.querySelectorAll(':scope > li').forEach(function (li) {
        var hit = !q || li.textContent.toLowerCase().indexOf(q) >= 0;
        li.hidden = !hit;
        li.querySelectorAll('li').forEach(function (sub) {
          sub.hidden = q !== '' && sub.textContent.toLowerCase().indexOf(q) < 0
            && li.firstChild.textContent.toLowerCase().indexOf(q) < 0;
        });
        if (hit) shown++;
      });
      ul.hidden = shown === 0;
      ul.previousElementSibling.hidden = shown === 0;
      any = any || shown > 0;
    });
    aside.querySelector('.none').style.display = any ? 'none' : 'block';
  });

  // Small screens: the sidebar is a full-screen menu.
  var menu = document.getElementById('menu');
  function setOpen(open) {
    document.body.classList.toggle('nav-open', open);
    menu.setAttribute('aria-expanded', String(open));
    menu.textContent = open ? 'Close' : 'Contents';
  }
  menu.addEventListener('click', function () { setOpen(!document.body.classList.contains('nav-open')); });
  aside.addEventListener('click', function (e) { if (e.target.tagName === 'A') setOpen(false); });
</script>
</body>
</html>
''';
