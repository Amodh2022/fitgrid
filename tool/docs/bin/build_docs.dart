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
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
  <style>
    :root { --fg:#0f172a; --muted:#475569; --bg:#ffffff; --card:#f1f5f9; --line:#e2e8f0; --accent:#2563eb; --accent-soft:#dbeafe; }
    @media (prefers-color-scheme: dark) { :root { --fg:#e2e8f0; --muted:#94a3b8; --bg:#0b1120; --card:#1e293b; --line:#1e293b; --accent:#60a5fa; --accent-soft:#172554; } }
    * { box-sizing:border-box; }
    html { scroll-padding-top:72px; }
    body { margin:0; font:16px/1.65 system-ui,-apple-system,Segoe UI,Roboto,sans-serif; color:var(--fg); background:var(--bg); }
    a { color:var(--accent); }

    header.top { position:sticky; top:0; z-index:10; display:flex; align-items:center; gap:16px; height:56px; padding:0 16px; background:var(--bg); border-bottom:1px solid var(--line); }
    header.top .brand { font-weight:700; font-size:1.1rem; color:var(--fg); text-decoration:none; }
    header.top .brand span { color:var(--muted); font-weight:500; }
    header.top .version { font:12px ui-monospace,SFMono-Regular,Menlo,monospace; color:var(--muted); background:var(--card); padding:2px 8px; border-radius:999px; }
    header.top nav { margin-left:auto; display:flex; gap:18px; }
    header.top nav a { color:var(--muted); text-decoration:none; font-size:.95rem; }
    header.top nav a:hover { color:var(--fg); }
    #menu { display:none; margin-left:auto; background:var(--card); color:var(--fg); border:0; border-radius:8px; padding:6px 12px; font:inherit; cursor:pointer; }

    .layout { display:grid; grid-template-columns:272px minmax(0,1fr); max-width:1240px; margin:0 auto; }
    aside { position:sticky; top:56px; height:calc(100vh - 56px); overflow-y:auto; padding:20px 16px 48px; border-right:1px solid var(--line); }
    aside input { width:100%; padding:8px 10px; border:1px solid var(--line); border-radius:8px; background:var(--card); color:var(--fg); font:inherit; font-size:.9rem; }
    aside input:focus { outline:2px solid var(--accent); outline-offset:-1px; }
    aside p.group { margin:22px 0 6px; font-size:.75rem; font-weight:700; letter-spacing:.06em; text-transform:uppercase; color:var(--muted); }
    aside ul { list-style:none; margin:0; padding:0; }
    aside a { display:block; padding:4px 10px; border-radius:6px; color:var(--fg); text-decoration:none; font-size:.92rem; line-height:1.4; }
    aside a:hover { background:var(--card); }
    aside ul ul { display:none; margin:2px 0 4px 10px; border-left:1px solid var(--line); }
    aside ul ul a { font-size:.85rem; color:var(--muted); padding:3px 10px; }
    aside li.open > ul, aside.searching ul ul { display:block; }
    aside a.active { background:var(--accent-soft); color:var(--accent); font-weight:600; }
    aside .none { display:none; color:var(--muted); font-size:.9rem; margin-top:16px; }

    article { min-width:0; padding:32px 48px 96px; max-width:880px; }
    article h1 { font-size:2.3rem; line-height:1.2; margin:0 0 12px; }
    article h2 { font-size:1.6rem; margin:64px 0 12px; padding-top:8px; border-top:1px solid var(--line); }
    article h3 { font-size:1.2rem; margin:36px 0 8px; }
    article h2, article h3 { position:relative; }
    .anchor { margin-left:8px; color:var(--muted); text-decoration:none; opacity:0; }
    h2:hover .anchor, h3:hover .anchor, .anchor:focus { opacity:1; }
    .intro { font-size:1.08rem; }
    .intro > p:first-of-type { font-size:1.2rem; color:var(--muted); }
    .buttons a { display:inline-block; margin:8px 8px 0 0; padding:9px 16px; border-radius:8px; background:var(--accent); color:#fff; text-decoration:none; font-weight:600; font-size:.95rem; }
    .buttons a.secondary { background:var(--card); color:var(--fg); }
    img { max-width:100%; height:auto; border-radius:12px; border:1px solid var(--line); }
    code { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:.88em; }
    :not(pre) > code { background:var(--card); padding:.12em .38em; border-radius:5px; }
    pre { position:relative; background:var(--card); padding:16px; border-radius:10px; overflow-x:auto; line-height:1.5; }
    pre code.hljs { background:none; padding:0; }
    pre button.copy { position:absolute; top:8px; right:8px; padding:3px 10px; font:12px system-ui,sans-serif; border:1px solid var(--line); border-radius:6px; background:var(--bg); color:var(--muted); cursor:pointer; opacity:0; transition:opacity .15s; }
    pre:hover button.copy, pre button.copy:focus { opacity:1; }
    .table { overflow-x:auto; margin:16px 0; }
    table { border-collapse:collapse; width:100%; font-size:.92rem; }
    th, td { text-align:left; padding:8px 10px; border-bottom:1px solid var(--line); vertical-align:top; }
    th { background:var(--card); }
    blockquote { margin:16px 0; padding:4px 16px; border-left:4px solid var(--accent); background:var(--card); border-radius:0 8px 8px 0; }
    hr { border:0; border-top:1px solid var(--line); margin:32px 0; }
    footer { color:var(--muted); margin-top:64px; font-size:.9rem; border-top:1px solid var(--line); padding-top:16px; }

    @media (max-width:900px) {
      header.top nav { display:none; }
      #menu { display:block; }
      .layout { display:block; }
      aside { display:none; position:fixed; top:56px; left:0; right:0; bottom:0; height:auto; z-index:9; background:var(--bg); border-right:0; }
      body.nav-open aside { display:block; }
      body.nav-open { overflow:hidden; }
      article { padding:24px 16px 72px; }
      article h1 { font-size:1.8rem; }
      .anchor { display:none; }
    }
  </style>
</head>
<body>
<header class="top">
  <a class="brand" href="./">fitgrid <span>docs</span></a>
  ${version.isEmpty ? '' : '<span class="version">v$version</span>'}
  <nav>
    <a href="demo/">Live demo</a>
    <a href="https://pub.dev/documentation/fitgrid_table/latest/">API reference</a>
    <a href="https://pub.dev/packages/fitgrid_table">pub.dev</a>
    <a href="$_repo">GitHub</a>
  </nav>
  <button id="menu" aria-expanded="false" aria-controls="sidebar">Contents</button>
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
