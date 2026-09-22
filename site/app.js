const apps = {
  xcode: { name: 'Xcode', emoji: '🛠️', title: 'Building in Xcode' },
  figma: { name: 'Figma', emoji: '🎨', title: 'Designing in Figma' },
  music: { name: 'Music', emoji: '🎧', title: 'Listening in Music' },
  journal: { name: 'Journal', emoji: '☾', title: 'Nothing shared', detail: 'Journal is ignored', off: true }
};
const keys = Object.keys(apps);
const $ = selector => document.querySelector(selector);
const desktop = $('.desktop');
const cursor = $('#cursor');
const playButton = $('#play');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let target = 'xcode';
let playing = !reducedMotion.matches;
let onScreen = false;
let steps = [];
let loop;

const next = () => keys[(keys.indexOf(target) + 1) % keys.length];
const replay = (element, className) => {
  element.classList.remove(className);
  void element.getBoundingClientRect();
  element.classList.add(className);
};

function pointAt(key) {
  const box = desktop.getBoundingClientRect();
  const icon = desktop.querySelector(`[data-icon="${key}"]`).getBoundingClientRect();
  cursor.style.transform = `translate(${icon.left - box.left + icon.width * .5}px, ${icon.top - box.top + icon.height * .4}px)`;
}

function activate(key) {
  const app = apps[key];
  $('#menu-app').textContent = app.name;
  $('#window-title').textContent = app.name;
  const appWindow = $('#window');
  appWindow.dataset.app = key;
  replay(appWindow, 'changed');
  for (const icon of desktop.querySelectorAll('[data-icon]')) icon.classList.toggle('active', icon.dataset.icon === key);
  for (const button of document.querySelectorAll('[data-app]')) button.setAttribute('aria-pressed', String(button.dataset.app === key));
}

function share(key) {
  const app = apps[key];
  $('#emoji').textContent = app.emoji;
  $('#status-title').textContent = app.title;
  $('#status-detail').textContent = app.detail ?? 'Visible to your teammates';
  const live = $('#live-label');
  live.classList.toggle('off', Boolean(app.off));
  live.textContent = app.off ? 'Not sharing' : 'Sharing';
  replay($('#popover'), 'changed');
  replay($('#menu-mark'), 'pulse');
}

function schedule(delay) {
  clearTimeout(loop);
  if (playing && onScreen) loop = setTimeout(() => go(next()), delay);
}

// Point at the Dock, click, switch apps, then update the status after a short pause.
function go(key) {
  steps.forEach(clearTimeout);
  target = key;
  if (reducedMotion.matches) {
    activate(key);
    share(key);
    steps = [];
  } else {
    pointAt(key);
    steps = [
      setTimeout(() => {
        replay(cursor, 'press');
        replay(desktop.querySelector(`[data-icon="${key}"]`), 'launch');
      }, 750),
      setTimeout(() => activate(key), 900),
      setTimeout(() => share(key), 1700)
    ];
  }
  schedule(4000);
}

function setPlaying(value) {
  playing = value;
  playButton.classList.toggle('paused', !value);
  playButton.setAttribute('aria-label', value ? 'Pause demo' : 'Play demo');
  if (value) schedule(400);
  else clearTimeout(loop);
}

for (const button of document.querySelectorAll('[data-app]')) {
  button.addEventListener('click', () => {
    const app = apps[button.dataset.app];
    setPlaying(false);
    go(button.dataset.app);
    $('#announce').textContent = `${app.name}: ${app.title}`;
  });
}
playButton.addEventListener('click', () => setPlaying(!playing));
setPlaying(playing);
new IntersectionObserver(([entry]) => {
  onScreen = entry.isIntersecting;
  if (onScreen) schedule(1200);
  else clearTimeout(loop);
}, { threshold: .4 }).observe(desktop);
addEventListener('resize', () => {
  if (cursor.style.transform) pointAt(target);
});

// Set release.json only after a signed release is publicly available.
fetch('release.json').then(response => response.ok ? response.json() : null).then(release => {
  if (!release?.url || !release?.version) return;
  const url = new URL(release.url);
  if (url.origin !== 'https://github.com' || !url.pathname.startsWith('/noelrohi/nowish/releases/download/')) return;
  for (const link of document.querySelectorAll('.release-link')) {
    link.href = url.href;
    link.textContent = 'Download for macOS ↓';
  }
  document.querySelector('#availability').textContent = `Version ${release.version} · macOS 14+`;
}).catch(() => {});
