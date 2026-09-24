// Mirrors AppActivity: title = prefix + (display name or app name); {app} in a subtitle becomes the app name.
const apps = {
  finder: { name: 'Finder', emoji: '🗂️', prefix: 'Browsing in', displayName: '', subtitle: '', glow: 'gray', shared: false },
  safari: { name: 'Safari', emoji: '🧭', prefix: 'Browsing', displayName: 'the web', subtitle: '', glow: 'blue', shared: true },
  xcode: { name: 'Xcode', emoji: '🛠️', prefix: 'Building in', displayName: '', subtitle: 'Shipping Nowish', glow: 'blue', shared: true },
  figma: { name: 'Figma', emoji: '🎨', prefix: 'Designing in', displayName: '', subtitle: 'Pushing pixels', glow: 'purple', shared: true },
  slack: { name: 'Slack', emoji: '💬', prefix: 'Catching up in', displayName: '', subtitle: '', glow: 'pink', shared: true },
  music: { name: 'Music', emoji: '🎧', prefix: 'Listening to', displayName: 'music', subtitle: 'Headphones on', glow: 'red', shared: true },
  journal: { name: 'Journal', emoji: '📓', prefix: 'Writing in', displayName: '', subtitle: '', glow: 'orange', shared: false }
};
// Roam's named glow colors.
const glows = { blue: '#3b82f6', gold: '#d4a72c', gray: '#8e8e93', green: '#30d158', indigo: '#5e5ce6', lime: '#a3e635', orange: '#ff9f0a', pink: '#ff4f9a', purple: '#a259ff', red: '#ff453a', teal: '#40c8e0', yellow: '#ffd60a' };
const emojis = ['💻', '🛠️', '🎨', '🧭', '🎧', '💬', '📓', '🗂️', '📝', '🚀', '🌐', '🎮'];
const presets = {
  app: { title: 'Xcode', hint: 'Just the app’s name' },
  working: { title: 'Working with Xcode', hint: 'Working with {app}' },
  custom: { title: 'Heads down in Xcode', hint: 'Your template: Heads down in {app}' }
};
const displayName = app => app.displayName.trim() || app.name;
const titleOf = app => [app.prefix.trim(), displayName(app)].filter(Boolean).join(' ');
const subtitleOf = app => app.subtitle.replaceAll('{app}', app.name).trim();
const glowOf = app => glows[app.glow] ?? '#5b5b70';
const tour = ['figma', 'music', 'journal', 'slack', 'safari', 'xcode'];
const SETTLE = 2000;
const $ = selector => document.querySelector(selector);
const root = document.documentElement;
const mark = $('#mark');
const popover = $('#popover');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const state = { front: 'xcode', shown: 'xcode', sharing: true, running: true, touched: false, editing: 'xcode' };
let settleTimer;
let tourTimer;
let heroVisible = true;

function activity() {
  const app = apps[state.shown];
  if (!state.running) return { reason: 'Nowish quit · activity cleared' };
  if (!state.sharing) return { reason: 'Sharing is off' };
  if (!app.shared) return { reason: `${app.name} is ignored` };
  return app;
}

function render() {
  const current = activity();
  const preview = $('#preview');
  root.style.setProperty('--glow', current.reason ? '#5b5b70' : glowOf(current));
  preview.classList.toggle('empty', Boolean(current.reason));
  $('#preview-emoji').textContent = current.reason ? '☾' : current.emoji;
  $('#preview-title').textContent = current.reason ?? titleOf(current);
  $('#preview-subtitle').textContent = current.reason ? '' : subtitleOf(current);
  $('#pop-status').textContent = !state.running || !state.sharing ? 'Sharing is off' : current.reason ?? 'Sharing with Roam';
  $('#pop-dot').classList.toggle('off', Boolean(current.reason));
  $('#sharing').setAttribute('aria-checked', String(state.sharing && state.running));
  $('#ignore').textContent = `${apps[state.front].shared ? 'Ignore' : 'Share'} ${apps[state.front].name}`;
  mark.classList.toggle('off', Boolean(current.reason));
  $('#announce').textContent = current.reason ?? `Your Roam status: ${current.emoji} ${titleOf(current)}`;
  preview.classList.remove('changed');
  void preview.offsetWidth;
  preview.classList.add('changed');
  $('#demo-share').setAttribute('aria-checked', String(state.sharing && state.running));
  $('#demo-status').classList.toggle('empty', Boolean(current.reason));
  $('#demo-status-emoji').textContent = current.reason ? '☾' : current.emoji;
  $('#demo-status-title').textContent = current.reason ?? titleOf(current);
  $('#demo-share-note').textContent = current.reason ? 'Status cleared' : 'Following your focus';
  renderList();
  renderEditor();
}

function renderList() {
  for (const row of document.querySelectorAll('#app-list li')) {
    const app = apps[row.dataset.app];
    row.classList.toggle('ignored', !app.shared);
    row.querySelector('.row').setAttribute('aria-current', String(row.dataset.app === state.editing));
    row.querySelector('.row span').textContent = app.shared ? `${app.emoji} ${titleOf(app)}` : 'Not shared';
    row.querySelector('.switch').setAttribute('aria-checked', String(app.shared));
  }
}

function renderEditor() {
  const app = apps[state.editing];
  const editor = $('#editor');
  editor.style.setProperty('--app-glow', glowOf(app));
  editor.classList.toggle('no-glow', !glows[app.glow]);
  editor.classList.toggle('ignored', !app.shared);
  $('#ed-preview-emoji').textContent = app.emoji;
  $('#ed-preview-prefix').textContent = app.prefix.trim();
  $('#ed-preview-name').textContent = displayName(app);
  $('#ed-preview-subtitle').textContent = subtitleOf(app);
  $('#ed-share').setAttribute('aria-checked', String(app.shared));
  $('#ed-name').placeholder = app.name;
  // Leave the field being typed in alone so the caret does not jump.
  for (const [id, key] of [['#ed-prefix', 'prefix'], ['#ed-name', 'displayName'], ['#ed-subtitle', 'subtitle']]) {
    if (document.activeElement !== $(id)) $(id).value = app[key];
  }
  for (const button of document.querySelectorAll('#emoji-picks button')) button.setAttribute('aria-checked', String(button.textContent === app.emoji));
  for (const button of document.querySelectorAll('#swatches button')) button.setAttribute('aria-checked', String(button.dataset.glow === app.glow));
}

// The tour mirrors the app: shared apps settle for two seconds, ignored apps clear at once.
// Clicks publish instantly so the demo answers straight away.
function focus(key, instant = false) {
  state.front = key;
  $('#menu-app').textContent = apps[key].name;
  for (const button of document.querySelectorAll('.dock [data-app]')) button.setAttribute('aria-pressed', String(button.dataset.app === key));
  const icon = $(`.dock [data-app="${key}"]`);
  icon.classList.remove('bounce');
  void icon.offsetWidth;
  icon.classList.add('bounce');
  clearTimeout(settleTimer);
  mark.classList.remove('settling');
  renderList();
  $('#ignore').textContent = `${apps[key].shared ? 'Ignore' : 'Share'} ${apps[key].name}`;
  if (instant || !apps[key].shared || reducedMotion.matches) return publish(key);
  mark.classList.add('settling');
  settleTimer = setTimeout(() => publish(key), SETTLE);
}

function publish(key) {
  mark.classList.remove('settling');
  state.shown = key;
  render();
}

function setOpen(open) {
  popover.classList.toggle('open', open);
  mark.setAttribute('aria-expanded', String(open));
}

function stopTour() {
  state.touched = true;
  clearTimeout(tourTimer);
  $('#hint').classList.add('gone');
}

function scheduleTour() {
  clearTimeout(tourTimer);
  if (state.touched || reducedMotion.matches || !heroVisible || document.hidden) return;
  tourTimer = setTimeout(() => {
    focus(tour[(tour.indexOf(state.front) + 1) % tour.length]);
    scheduleTour();
  }, 4800);
}

$('#app-list').innerHTML = Object.entries(apps).map(([key, app]) => `
  <li data-app="${key}">
    <button class="row" type="button" aria-label="Edit ${app.name}">
      <img src="assets/apps/${key}.png" alt="" width="32" height="32">
      <div><strong>${app.name}</strong><span></span></div>
    </button>
    <button class="switch" type="button" role="switch" aria-label="Share ${app.name}"><i></i></button>
  </li>`).join('');
$('#emoji-picks').innerHTML = emojis.map(emoji => `<button type="button" role="radio" aria-label="${emoji}">${emoji}</button>`).join('');
$('#emoji-picks').setAttribute('role', 'radiogroup');
$('#swatches').innerHTML = ['none', ...Object.keys(glows)].map(name => `<button type="button" role="radio" data-glow="${name}" aria-label="${name[0].toUpperCase() + name.slice(1)}" title="${name[0].toUpperCase() + name.slice(1)}"></button>`).join('');
// The CSP blocks inline style attributes, so set swatch colors through CSSOM.
for (const button of document.querySelectorAll('#swatches button')) button.style.setProperty('--swatch', glows[button.dataset.glow] ?? 'transparent');
$('#swatches').setAttribute('role', 'radiogroup');

for (const button of document.querySelectorAll('.dock [data-app]')) {
  button.addEventListener('click', () => {
    stopTour();
    focus(button.dataset.app, true);
    if (state.running) setOpen(true);
  });
}
$('#app-list').addEventListener('click', event => {
  const item = event.target.closest('li');
  if (!item) return;
  const key = item.dataset.app;
  if (event.target.closest('.switch')) {
    apps[key].shared = !apps[key].shared;
    return render();
  }
  state.editing = key;
  stopTour();
  focus(key, true);
});

// Editing the app that is on screen updates the menu bar straight away.
function edit(change) {
  change(apps[state.editing]);
  if (state.editing === state.shown) render();
  else { renderList(); renderEditor(); }
}
$('#editor').addEventListener('submit', event => event.preventDefault());
$('#ed-prefix').addEventListener('input', event => edit(app => { app.prefix = event.target.value; }));
$('#ed-name').addEventListener('input', event => edit(app => { app.displayName = event.target.value; }));
$('#ed-subtitle').addEventListener('input', event => edit(app => { app.subtitle = event.target.value; }));
$('#ed-share').addEventListener('click', () => edit(app => { app.shared = !app.shared; }));
$('#emoji-picks').addEventListener('click', event => {
  const button = event.target.closest('button');
  if (button) edit(app => { app.emoji = button.textContent; });
});
$('#swatches').addEventListener('click', event => {
  const button = event.target.closest('button');
  if (button) edit(app => { app.glow = button.dataset.glow; });
});
// Point at the part of the status each field controls.
for (const type of ['focusin', 'pointerover']) {
  $('#editor').addEventListener(type, event => {
    const part = event.target.closest('[data-part]')?.dataset.part;
    if (part) $('#big-preview').dataset.focus = part;
  });
}
$('#editor').addEventListener('focusout', () => delete $('#big-preview').dataset.focus);
$('#editor').addEventListener('pointerleave', () => {
  if (!$('#editor').contains(document.activeElement)) delete $('#big-preview').dataset.focus;
});

for (const button of document.querySelectorAll('.segmented button')) {
  button.addEventListener('click', () => {
    for (const other of document.querySelectorAll('.segmented button')) other.setAttribute('aria-checked', String(other === button));
    $('#preset-title').textContent = presets[button.dataset.preset].title;
    $('#preset-hint').textContent = presets[button.dataset.preset].hint;
  });
}
$('#demo-share').addEventListener('click', () => {
  if (!state.running) state.running = true;
  else state.sharing = !state.sharing;
  render();
});
$('#sharing').addEventListener('click', () => {
  if (!state.running) state.running = true;
  else state.sharing = !state.sharing;
  render();
});
$('#ignore').addEventListener('click', () => {
  apps[state.front].shared = !apps[state.front].shared;
  publish(state.front);
});
$('#quit').addEventListener('click', () => {
  state.running = false;
  setOpen(false);
  render();
});
mark.addEventListener('click', () => {
  if (!state.running) {
    state.running = true;
    render();
    return setOpen(true);
  }
  setOpen(!popover.classList.contains('open'));
});
popover.addEventListener('click', event => {
  if (event.target.closest('a')) setOpen(false);
});
document.addEventListener('pointerdown', event => {
  if (!event.target.closest('#popover, #mark, .dock')) setOpen(false);
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape') setOpen(false);
});
document.addEventListener('visibilitychange', scheduleTour);
new IntersectionObserver(([entry]) => {
  heroVisible = entry.isIntersecting;
  if (heroVisible) return scheduleTour();
  clearTimeout(tourTimer);
  // The menu would cover the sections below; the menu bar icon still reopens it.
  setOpen(false);
}, { threshold: .5 }).observe($('.desktop'));

function tick() {
  $('#clock').textContent = new Date().toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}
tick();
setInterval(tick, 15000);
render();
setOpen(innerWidth >= 1180);

// Set release.json only after a signed release is publicly available.
fetch('release.json').then(response => response.ok ? response.json() : null).then(release => {
  if (!release?.url || !release?.version) return;
  const url = new URL(release.url);
  if (url.origin !== 'https://github.com' || !url.pathname.startsWith('/noelrohi/nowish/releases/download/')) return;
  for (const link of document.querySelectorAll('.release-link')) link.href = url.href;
  $('#availability').textContent = `Version ${release.version} · macOS 14+ · Apple silicon & Intel`;
}).catch(() => {});
