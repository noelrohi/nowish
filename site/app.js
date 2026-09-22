const examples = {
  xcode: { name: 'Xcode', icon: '⌘', emoji: '🛠️', title: 'Building in Xcode' },
  figma: { name: 'Figma', icon: '◈', emoji: '🎨', title: 'Designing in Figma' },
  music: { name: 'Music', icon: '♫', emoji: '🎧', title: 'Listening in Music' },
  private: { name: 'Ignored app', icon: '−', emoji: '☾', title: 'Activity cleared' }
};
for (const button of document.querySelectorAll('[data-app]')) {
  button.addEventListener('click', () => {
    const key = button.dataset.app;
    const example = examples[key];
    document.querySelector('#menu-app').textContent = example.name;
    document.querySelector('#context-name').textContent = example.name;
    document.querySelector('#context-icon').textContent = example.icon;
    document.querySelector('#emoji').textContent = example.emoji;
    document.querySelector('#activity-title').textContent = example.title;
    document.querySelector('#activity-detail').textContent = key === 'private' ? 'Some things are just for you.' : 'A little context for your teammates.';
    const status = document.querySelector('#live-label');
    status.classList.toggle('off', key === 'private');
    status.replaceChildren(Object.assign(document.createElement('i')), document.createTextNode(key === 'private' ? 'Not sharing' : 'Sharing'));
    for (const other of document.querySelectorAll('[data-app]')) other.setAttribute('aria-pressed', String(other === button));
  });
}
// Set release.json only after a signed release is publicly available.
fetch('release.json').then(response => response.ok ? response.json() : null).then(release => {
  if (!release?.url || !release?.version) return;
  const url = new URL(release.url);
  if (url.origin !== 'https://github.com' || !url.pathname.startsWith('/noelrohi/nowish/releases/download/')) return;
  const link = document.querySelector('#release-link');
  link.href = url.href;
  link.textContent = 'Download for macOS ↓';
  document.querySelector('#availability').textContent = `Version ${release.version} · macOS 14+`;
}).catch(() => {});
