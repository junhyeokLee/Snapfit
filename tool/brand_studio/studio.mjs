const tabs = [...document.querySelectorAll('[role=tab]')];
const panels = [...document.querySelectorAll('[role=tabpanel]')];
const orientationButtons = [...document.querySelectorAll('[data-orientation]')];
const splashImage = document.getElementById('splashImage');
const download = document.getElementById('splashDownload');
const portraitViewport = matchMedia('(orientation: portrait)');
let manuallySelected = false;

function selectTab(tab, focus = false) {
  for (const item of tabs) {
    const selected = item === tab;
    item.setAttribute('aria-selected', String(selected));
    item.tabIndex = selected ? 0 : -1;
  }
  for (const panel of panels) panel.hidden = panel.id !== tab.dataset.tab;
  if (focus) tab.focus();
}

function setOrientation(orientation) {
  const source = 'assets/splash-' + orientation + '.png';
  for (const button of orientationButtons) {
    button.setAttribute('aria-pressed', String(button.dataset.orientation === orientation));
  }
  splashImage.src = source;
  splashImage.alt = '해안 풍경과 커플 사진을 담은 ' + (orientation === 'portrait' ? '세로' : '가로') + ' SnapFit 스플래시 시안';
  download.href = source;
  download.download = 'snapfit-splash-' + orientation + '.png';
}

for (const [index, tab] of tabs.entries()) {
  tab.addEventListener('click', () => selectTab(tab));
  tab.addEventListener('keydown', event => {
    const next = {ArrowRight: (index + 1) % tabs.length, ArrowLeft: (index - 1 + tabs.length) % tabs.length, Home: 0, End: tabs.length - 1}[event.key];
    if (next === undefined) return;
    event.preventDefault();
    selectTab(tabs[next], true);
  });
}

for (const button of orientationButtons) {
  button.addEventListener('click', () => {
    manuallySelected = true;
    setOrientation(button.dataset.orientation);
  });
}
portraitViewport.addEventListener('change', event => {
  if (!manuallySelected) setOrientation(event.matches ? 'portrait' : 'landscape');
});
setOrientation(portraitViewport.matches ? 'portrait' : 'landscape');
const initialTab = tabs.find(tab => '#' + tab.dataset.tab === location.hash);
if (initialTab) selectTab(initialTab);
window.lucide.createIcons();
