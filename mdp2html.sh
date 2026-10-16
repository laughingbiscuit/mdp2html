#!/bin/sh
# Convert an mdp (github.com/visit1985/mdp) deck into a single self-contained web page.
set -eu

case ${1:-} in -h|--help) cat <<'EOF'; exit 0 ;; esac
usage: mdp2html.sh [slides.md] > slides.html
Reads stdin when no file is given. Needs awk and pandoc.
Keys: next = → space PgDn j l, back = ← Backspace PgUp k h, Home/End/g/G, f = fullscreen.
Click or swipe also works. The URL (#slide.step) links to the current slide.
EOF

name=$(basename "${1:-slides}")

# mdp syntax -> pandoc markdown. Title/author/date (%title: lines or a leading <!-- --> block)
# become a metadata block at the end.
awk -v name="${name%.*}" -v sq="'" '
function q(s) { gsub(sq, sq sq, s); return sq s sq }
function setmeta(s,  k) { k = s; sub(/^%/, "", k); sub(/:.*/, "", k); sub(/^[^:]*:[ \t]*/, "", s); meta[k] = s }
function center(s, level) { return "\n::: {.c" (level ? " .h" level : "") "}\n" s "\n:::\n" }
BEGIN { blank = 1; nbsp = "\302\240" }
NR == 1 && /^<!--/ { header = 1 }
header { if (/-->/) header = 0; else if (/^[a-z]+:/) setmeta($0); next }
{ after_blank = blank; blank = ($0 ~ /^[ \t]*$/) }
held != "" {   # a centred line underlined with === or --- is a centred heading (Setext)
  if (/^(=+|-+)[ \t]*$/) { print center(held, /^=/ ? 1 : 2); held = ""; next }
  print center(held, held_level); held = ""
}
/^[ \t]*```/ { fence = !fence; print; next }
fence { print; next }
code && blank { print "```"; code = 0 }
code { print; next }
pause && !blank {   # pause marker at the indent of the next line, so it stays inside nested lists
  match($0, /^[ \t]*/); print "\n" substr($0, 1, RLENGTH) "<div class=\"pause\"></div>\n"; pause = 0
}
after_blank && /^(    |\t)/ && !/^[ \t]*([-*+]|[0-9]+\.)[ \t]/ { print "```"; print; code = 1; next }  # verbatim
/^%[a-z]+:/ { setmeta($0); next }
after_blank && (/^[ \t]*-[ \t]*-[ \t]*-[- \t]*$/ || /^[ \t]*\*[ \t]*\*[ \t]*\*[* \t]*$/) {
  print "<hr class=\"slide\">\n"; next   # after text, --- is a Setext heading instead
}
/^[ \t]*(<[bB][rR]>|\^)[ \t]*$/ { pause = 1; next }
/^->.*<-[ \t]*$/ {
  held = $0; sub(/^->[ \t]*/, "", held); sub(/[ \t]*<-[ \t]*$/, "", held)
  held_level = match(held, /^#+/) ? RLENGTH : 0; sub(/^#+[ \t]*/, "", held); next
}
!/^[ \t]*([-*+]|[0-9]+\.|\|)[ \t]/ {   # keep spacing as typed (pandoc collapses it), except in lists/tables
  match($0, /^ */); lead = substr($0, 1, RLENGTH); rest = substr($0, RLENGTH + 1)
  if (!after_blank) gsub(/ /, nbsp, lead)
  gsub(/  /, " " nbsp, rest); $0 = lead rest
}
{ print }
END {
  if (held != "") print center(held, held_level)
  if (code) print "```"
  sep = (meta["author"] != "" && meta["date"] != "") ? " · " : ""
  print "\n---\npagetitle: " q(meta["title"] != "" ? meta["title"] : name)
  print "author: " q(meta["author"] sep meta["date"]) "\n---"
}
' "${1:--}" |
pandoc -f markdown-implicit_figures+hard_line_breaks -t html5 -s -A /dev/fd/3 3<<'EOF'
<style>
:root { --bg:#222733; --fg:#d8dee9; --muted:#8a93a6; --accent:#7fe9f3; --count:#f0952e;
  --status:#6aaa6e; --status-fg:#1c2a1d; --code:#2b3140; --line:#3a4152;
  --mono:"SF Mono", ui-monospace, Menlo, Consolas, monospace; }
html, body { margin:0; padding:0; max-width:none; height:100%; overflow:hidden;
  background:var(--bg); color:var(--fg); font-family:var(--mono); }
.slide { position:fixed; inset:0 0 4.2rem 0; box-sizing:border-box; padding:6vh 7vw; overflow:hidden;
  display:flex; flex-direction:column; justify-content:safe center;
  font-size:clamp(13px, 2.8vmin, 30px); line-height:1.45; }
.slide[hidden] { display:none; }
.slide > * { flex:none; margin:.45em 0; }
.slide h1, .slide h2, .slide h3, .c.h1, .c.h2 { color:var(--accent); font-weight:400; text-decoration:underline;
  text-underline-offset:.2em; text-decoration-thickness:2px; }
.slide h1 { font-size:1.35em; margin-bottom:.8em; }
.slide h2 { font-size:1.15em; }
.slide strong { color:#fff; }
.slide em, .slide a, .slide th { color:var(--accent); font-style:normal; font-weight:400; }
.slide li::marker { color:var(--count); }
.slide pre, .slide :not(pre) > code { background:var(--code); font-family:var(--mono); }
.slide pre { padding:.6em .9em; font-size:.82em; line-height:1.25; }
.slide table { border-collapse:collapse; font-size:.82em; }
.slide th, .slide td { border-bottom:1px solid var(--line); padding:.3em .8em; text-align:left; }
.slide blockquote { border-left:3px solid var(--accent); padding-left:1em; color:var(--muted); }
.c { text-align:center; }
.c.h1 { font-size:1.6em; }
.c.h2 { font-size:1.25em; }
.slide li > p, .slide li > ul, .slide li > ol { margin:0; }
.later { visibility:hidden; }
#pos { position:fixed; right:2.2rem; bottom:2.2rem; color:var(--count); font-size:20px; }
footer { position:fixed; left:0; right:0; bottom:0; height:1.8rem; display:flex; align-items:center;
  justify-content:space-between; gap:2em; padding:0 .8rem; font-size:15px; white-space:nowrap;
  overflow:hidden; background:var(--status); color:var(--status-fg); }
</style>
<script>
(() => {
  // Slides split at <hr class="slide">.
  const slides = [];
  for (const el of [...document.body.children]) {
    if (['SCRIPT', 'STYLE'].includes(el.tagName)) continue;
    if (!slides.length || el.matches('hr.slide')) slides.push(Object.assign(document.createElement('section'), { className: 'slide' }));
    el.matches('hr.slide') ? el.remove() : slides.at(-1).append(el);
  }
  const deck = slides.filter(s => s.children.length);
  // Everything after the n-th .pause of a slide appears at step n.
  for (const s of deck) {
    const marks = [...s.querySelectorAll('.pause')];
    s.dataset.steps = marks.length;
    for (const el of s.querySelectorAll('*')) {
      const n = marks.filter(m => m.compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING).length;
      if (n) el.dataset.step = n;
    }
  }
  const span = text => Object.assign(document.createElement('span'), { textContent: text });
  const pos = Object.assign(document.createElement('div'), { id: 'pos' });
  const footer = document.createElement('footer');
  footer.append(span('[0] ' + (document.querySelector('meta[name=author]')?.content || '')),
                span(`"${document.title}"`));
  document.body.prepend(...deck, pos, footer);

  // Shrink the text until the slide fits the window.
  const fit = s => {
    s.style.fontSize = '';
    let f = parseFloat(getComputedStyle(s).fontSize);
    while ((s.scrollHeight > s.clientHeight || s.scrollWidth > s.clientWidth) && f > 9)
      s.style.fontSize = (f *= 0.94) + 'px';
  };

  let i = 0, st = 0;
  const steps = () => +deck[i].dataset.steps;
  const go = (n, s = 0) => {
    i = Math.max(0, Math.min(deck.length - 1, n));
    st = Math.max(0, Math.min(steps(), s));
    deck.forEach((d, k) => { d.hidden = k !== i; });
    deck[i].querySelectorAll('[data-step]').forEach(e => e.classList.toggle('later', e.dataset.step > st));
    fit(deck[i]);
    pos.textContent = `${i + 1} / ${deck.length}`;
    history.replaceState(null, '', `#${i + 1}${st ? '.' + st : ''}`);
  };
  const next = () => st < steps() ? go(i, st + 1) : i < deck.length - 1 && go(i + 1);
  const prev = () => st > 0 ? go(i, st - 1) : i > 0 && go(i - 1, Infinity);  // going back shows the whole slide
  const fromHash = () => { const [n, s] = location.hash.slice(1).split('.').map(Number); go((n || 1) - 1, s || 0); };

  const keys = { ArrowRight: next, ArrowDown: next, ' ': next, PageDown: next, Enter: next, l: next, j: next,
    ArrowLeft: prev, ArrowUp: prev, PageUp: prev, Backspace: prev, h: prev, k: prev,
    Home: () => go(0), g: () => go(0), End: () => go(deck.length - 1), G: () => go(deck.length - 1),
    f: () => document.fullscreenElement ? document.exitFullscreen() : document.documentElement.requestFullscreen() };
  addEventListener('keydown', e => {
    const action = !e.metaKey && !e.ctrlKey && !e.altKey && keys[e.key];
    if (action) { e.preventDefault(); action(); }
  });
  addEventListener('click', e => {
    if (!e.target.closest('a') && !getSelection().toString()) (e.clientX < innerWidth / 3 ? prev : next)();
  });
  let x0;
  addEventListener('touchstart', e => { x0 = e.touches[0].clientX; }, { passive: true });
  addEventListener('touchend', e => {
    const dx = e.changedTouches[0].clientX - x0;
    if (Math.abs(dx) > 40) (dx < 0 ? next : prev)();
  });
  addEventListener('resize', () => fit(deck[i]));
  addEventListener('hashchange', fromHash);
  fromHash();
})();
</script>
EOF
