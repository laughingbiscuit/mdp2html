#!/bin/sh
# Convert an mdp (github.com/visit1985/mdp) deck into a single self-contained web page.
set -eu

case ${1:-} in -h|--help) cat <<'EOF'; exit 0 ;; esac
usage: mdp2html.sh [slides.md] > slides.html
Reads stdin when no file is given. Needs awk and pandoc.
Keys: next = → space PgDn j l, back = ← Backspace PgUp k h, Home/End, f = fullscreen.
Click or swipe also works. The URL (#slide.step) links to the current slide.
EOF

name=$(basename "${1:-slides}")

# mdp syntax -> pandoc markdown; %title/%author/%date become a metadata block at the end.
awk -v name="${name%.*}" -v sq="'" '
function q(s) { gsub(sq, sq sq, s); return sq s sq }
BEGIN { blank = 1 }
{ after_blank = blank; blank = ($0 ~ /^[ \t]*$/) }
/^[ \t]*```/ { fence = !fence; print; next }
fence { print; next }
code && blank { print "```"; code = 0 }
code { print; next }
after_blank && /^(    |\t)/ { print "```"; print; code = 1; next }   # indented block: verbatim
/^%[a-z]+:/ { k = $0; sub(/:.*/, "", k); sub(/^%[a-z]+:[ \t]*/, ""); meta[k] = $0; next }
/^(---+|\*\*\*+)[ \t]*$/ { print "\n<hr class=\"slide\">\n"; next }
/^[ \t]*(<[bB][rR]>|\^)[ \t]*$/ { print "\n<div class=\"pause\"></div>\n"; next }
/^->.*<-[ \t]*$/ {
  sub(/^->[ \t]*/, ""); sub(/[ \t]*<-[ \t]*$/, ""); big = sub(/^#+[ \t]+/, "")
  print "::: {.c" (big ? " .big" : "") "}\n" $0 "\n:::"; next
}
{ print }
END {
  if (code) print "```"
  sep = (meta["%author"] != "" && meta["%date"] != "") ? " · " : ""
  print "\n---\npagetitle: " q(meta["%title"] != "" ? meta["%title"] : name)
  print "author: " q(meta["%author"] sep meta["%date"]) "\n---"
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
.slide h1, .slide h2, .slide h3, .c.big { color:var(--accent); font-weight:400; text-decoration:underline;
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
.c.big { font-size:1.6em; }
.later { visibility:hidden; }
#pos { position:fixed; right:2.2rem; bottom:2.2rem; color:var(--count); font-size:20px; }
footer { position:fixed; left:0; right:0; bottom:0; height:1.8rem; display:flex; align-items:center;
  justify-content:space-between; gap:2em; padding:0 .8rem; font-size:15px; white-space:nowrap;
  overflow:hidden; background:var(--status); color:var(--status-fg); }
</style>
<script>
(() => {
  // Slides split at <hr class="slide">; within a slide, each .pause starts a new step.
  const slides = [];
  let slide, step;
  for (const el of [...document.body.children]) {
    if (['SCRIPT', 'STYLE'].includes(el.tagName)) continue;
    if (!slide || el.matches('hr.slide')) {
      slide = Object.assign(document.createElement('section'), { className: 'slide' });
      slide.dataset.steps = step = 0;
      slides.push(slide);
    }
    if (el.matches('.pause')) slide.dataset.steps = ++step;
    else if (!el.matches('hr.slide')) { if (step) el.dataset.step = step; slide.append(el); continue; }
    el.remove();
  }
  const deck = slides.filter(s => s.children.length);
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
    Home: () => go(0), End: () => go(deck.length - 1),
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
