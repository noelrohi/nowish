const apps = {
  finder: { name: 'Finder', emoji: '🗂️', title: 'Browsing in Finder', glow: '#8e8e93', shared: false },
  safari: { name: 'Safari', emoji: '🧭', title: 'Browsing in Safari', glow: '#2f9bff', shared: true },
  xcode: { name: 'Xcode', emoji: '🛠️', title: 'Building in Xcode', glow: '#3b82f6', shared: true },
  figma: { name: 'Figma', emoji: '🎨', title: 'Designing in Figma', glow: '#a259ff', shared: true },
  slack: { name: 'Slack', emoji: '💬', title: 'Chatting in Slack', glow: '#e01e5a', shared: true },
  music: { name: 'Music', emoji: '🎧', title: 'Listening in Music', glow: '#ff375f', shared: true },
  journal: { name: 'Journal', emoji: '📓', title: 'Writing in Journal', glow: '#ff9f5a', shared: false }
};
const tour = ['figma', 'music', 'journal', 'slack', 'safari', 'xcode'];
const SETTLE = 2000;
const $ = selector => document.querySelector(selector);
const root = document.documentElement;
const mark = $('#mark');
const popover = $('#popover');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const state = { front: 'xcode', shown: 'xcode', sharing: true, running: true, touched: false };
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
  root.style.setProperty('--glow', current.reason ? '#5b5b70' : current.glow);
  preview.classList.toggle('empty', Boolean(current.reason));
  $('#preview-emoji').textContent = current.reason ? '☾' : current.emoji;
  $('#preview-title').textContent = current.reason ?? current.title;
  $('#pop-status').textContent = !state.running || !state.sharing ? 'Sharing is off' : current.reason ?? 'Sharing with Roam';
  $('#pop-dot').classList.toggle('off', Boolean(current.reason));
  $('#sharing').setAttribute('aria-checked', String(state.sharing && state.running));
  $('#ignore').textContent = `${apps[state.front].shared ? 'Ignore' : 'Share'} ${apps[state.front].name}`;
  mark.classList.toggle('off', Boolean(current.reason));
  $('#announce').textContent = current.reason ?? `Your Roam status: ${current.emoji} ${current.title}`;
  preview.classList.remove('changed');
  void preview.offsetWidth;
  preview.classList.add('changed');
  renderList();
}

function renderList() {
  for (const row of document.querySelectorAll('#app-list li')) {
    const app = apps[row.dataset.app];
    row.classList.toggle('ignored', !app.shared);
    row.classList.toggle('front', row.dataset.app === state.front);
    row.querySelector('span').textContent = app.shared ? `${app.emoji} ${app.title}` : 'Ignored';
    row.querySelector('.switch').setAttribute('aria-checked', String(app.shared));
  }
}

// Mirror the app: shared apps settle for two seconds, ignored apps clear at once.
function focus(key) {
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
  if (!apps[key].shared || reducedMotion.matches) return publish(key);
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
    <img src="assets/apps/${key}.png" alt="" width="36" height="36">
    <div><strong>${app.name}</strong><span></span></div>
    <button class="switch" type="button" role="switch" aria-label="Share ${app.name}"><i></i></button>
  </li>`).join('');

for (const button of document.querySelectorAll('.dock [data-app]')) {
  button.addEventListener('click', () => {
    stopTour();
    focus(button.dataset.app);
    if (state.running) setOpen(true);
  });
}
$('#app-list').addEventListener('click', event => {
  const toggle = event.target.closest('.switch');
  if (!toggle) return;
  const key = toggle.closest('li').dataset.app;
  apps[key].shared = !apps[key].shared;
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
  if (heroVisible) scheduleTour();
  else clearTimeout(tourTimer);
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
