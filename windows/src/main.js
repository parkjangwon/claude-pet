const { app, BrowserWindow, ipcMain, screen, Tray, Menu, nativeImage } = require('electron');
const path = require('node:path');
const os = require('node:os');
const { execFile } = require('node:child_process');

const BASE_SPRITE = 32;
const DEFAULT_SCALE = 3;
const EFFECT_HEADROOM_RATIO = 1.3;
const COUNTER_HEIGHT = 32;
const DIALOGUE_WIDTH = 220;
const HUD_WIDTH = 376;
const HUD_HEIGHT = 310;
const PANEL_MARGIN = 24;

let petWindow;
let tray;
let store = loadStore();
let lastClaudeCpu;
let keyboardHookAvailable = false;

const assetRoot = app.isPackaged
  ? path.join(process.resourcesPath, 'ClaudePet', 'Assets.xcassets')
  : path.resolve(__dirname, '../../ClaudePet/Assets.xcassets');
const iconPath = path.join(assetRoot, 'AppIcon.appiconset', 'Icon_composer-iOS-Default-1024x1024@1x.png');

function loadStore() {
  try {
    const raw = require('node:fs').readFileSync(path.join(app.getPath('userData'), 'state.json'), 'utf8');
    return { ...defaultStore(), ...JSON.parse(raw) };
  } catch {
    return defaultStore();
  }
}

function defaultStore() {
  return {
    scaleIndex: 1,
    hideTaskbar: false,
    hunger: 100,
    affinityLevel: 1,
    affinityExp: 0,
    typingCount: 0
  };
}

function saveStore() {
  require('node:fs').mkdirSync(app.getPath('userData'), { recursive: true });
  require('node:fs').writeFileSync(path.join(app.getPath('userData'), 'state.json'), JSON.stringify(store, null, 2));
}

function spriteScale() {
  if (store.scaleIndex === 0) return 1.5;
  if (store.scaleIndex === 2) return 6;
  return DEFAULT_SCALE;
}

function uiScale() {
  return spriteScale() / DEFAULT_SCALE;
}

function windowSize() {
  const sprite = BASE_SPRITE * spriteScale();
  const scale = uiScale();
  const panelWidth = Math.max(DIALOGUE_WIDTH, HUD_WIDTH) + PANEL_MARGIN;
  const spriteLayerHeight = sprite + sprite * EFFECT_HEADROOM_RATIO + COUNTER_HEIGHT * scale;
  const hudLayerHeight = COUNTER_HEIGHT * scale + sprite + 6 * scale + HUD_HEIGHT;
  return {
    width: Math.round(Math.max(sprite, panelWidth)),
    height: Math.round(Math.max(spriteLayerHeight, hudLayerHeight)),
    sprite
  };
}

function createWindow() {
  const { width, height, sprite } = windowSize();
  const work = screen.getPrimaryDisplay().workArea;
  const desiredX = work.x + work.width - width / 2 - sprite / 2;

  petWindow = new BrowserWindow({
    width,
    height,
    x: Math.round(Math.max(work.x, Math.min(work.x + work.width - width, desiredX))),
    y: Math.round(work.y + work.height - height + 10),
    frame: false,
    transparent: true,
    resizable: false,
    movable: false,
    hasShadow: false,
    skipTaskbar: store.hideTaskbar,
    alwaysOnTop: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true
    }
  });

  petWindow.setAlwaysOnTop(true, 'screen-saver');
  petWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  petWindow.loadFile(path.join(__dirname, 'renderer.html'));
}

function createTray() {
  const icon = nativeImage.createFromPath(iconPath).resize({ width: 16, height: 16 });
  tray = new Tray(icon);
  tray.setToolTip('ClaudePet');
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: 'ClaudePet 보이기', click: () => petWindow?.show() },
    { label: '작게', type: 'radio', checked: store.scaleIndex === 0, click: () => setScale(0) },
    { label: '보통', type: 'radio', checked: store.scaleIndex === 1, click: () => setScale(1) },
    { label: '크게', type: 'radio', checked: store.scaleIndex === 2, click: () => setScale(2) },
    { type: 'separator' },
    { label: '종료', click: () => app.quit() }
  ]));
}

function setScale(index) {
  store.scaleIndex = index;
  saveStore();
  const { width, height } = windowSize();
  const pos = petWindow.getBounds();
  const work = screen.getPrimaryDisplay().workArea;
  const oldCenterX = pos.x + pos.width / 2;
  const nextX = oldCenterX - width / 2;
  petWindow.setBounds({
    x: Math.round(Math.max(work.x, Math.min(work.x + work.width - width, nextX))),
    y: pos.y + pos.height - height,
    width,
    height
  });
  petWindow.webContents.send('settings', publicState());
  createTray();
}

function publicState() {
  return {
    ...store,
    assetRoot,
    spriteScale: spriteScale(),
    uiScale: uiScale(),
    platform: os.platform(),
    keyboardHookAvailable
  };
}

function incrementTypingCount() {
  store.typingCount += 1;
  saveStore();
  petWindow?.webContents.send('typing-count', store.typingCount);
}

function registerKeyboardCounter() {
  try {
    const { uIOhook } = require('uiohook-napi');
    uIOhook.on('keyup', incrementTypingCount);
    uIOhook.start();
    keyboardHookAvailable = true;
    petWindow?.webContents.send('settings', publicState());
    return;
  } catch {
    keyboardHookAvailable = false;
    petWindow?.webContents.send('keyboard-hook-unavailable');
  }
}

function pollClaudeCpu() {
  if (process.platform !== 'win32') return;
  execFile('powershell.exe', [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-Command',
    "Get-Process Claude -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty CPU"
  ], { windowsHide: true, timeout: 1500 }, (err, stdout) => {
    const totalSeconds = Number.parseFloat(String(stdout).trim());
    if (!Number.isFinite(totalSeconds)) {
      lastClaudeCpu = undefined;
      petWindow?.webContents.send('claude-running', false);
      return;
    }

    petWindow?.webContents.send('claude-running', true);
    if (lastClaudeCpu !== undefined) {
      const delta = totalSeconds - lastClaudeCpu;
      petWindow?.webContents.send('claude-cpu', Math.max(0, delta * 100));
    }
    lastClaudeCpu = totalSeconds;
  });
}

ipcMain.handle('state', () => publicState());

ipcMain.on('move-by', (_event, dx) => {
  const b = petWindow.getBounds();
  const work = screen.getPrimaryDisplay().workArea;
  const x = Math.max(work.x, Math.min(work.x + work.width - b.width, b.x + dx));
  petWindow.setBounds({ ...b, x });
});

ipcMain.on('reset-position', () => {
  const { width, height } = windowSize();
  const work = screen.getPrimaryDisplay().workArea;
  petWindow.setBounds({
    x: Math.round(work.x + work.width - width),
    y: Math.round(work.y + work.height - height + 10),
    width,
    height
  });
});

ipcMain.on('feed', () => {
  if (store.typingCount < 100 || store.hunger + 10 > 100) return;
  store.typingCount -= 100;
  store.hunger = Math.min(100, store.hunger + 10);
  store.affinityExp += 1;
  const required = Math.round(20 * Math.pow(1.15, Math.max(0, store.affinityLevel - 1)));
  if (store.affinityExp >= required) {
    store.affinityExp = 0;
    store.affinityLevel = Math.min(100, store.affinityLevel + 1);
  }
  saveStore();
  petWindow.webContents.send('settings', publicState());
});

ipcMain.on('typing', () => {
  incrementTypingCount();
});

ipcMain.on('set-scale', (_event, index) => {
  const numericIndex = Number.isFinite(Number(index)) ? Number(index) : 1;
  setScale(Math.max(0, Math.min(2, numericIndex)));
});

ipcMain.on('hunger', (_event, hunger) => {
  store.hunger = hunger;
  saveStore();
});

ipcMain.on('hide-taskbar', (_event, hide) => {
  store.hideTaskbar = Boolean(hide);
  petWindow.setSkipTaskbar(store.hideTaskbar);
  saveStore();
});

ipcMain.on('quit', () => app.quit());

app.whenReady().then(() => {
  app.setName('ClaudePet');
  createWindow();
  createTray();
  registerKeyboardCounter();
  setInterval(pollClaudeCpu, 1000);
});

app.on('will-quit', () => {
  try {
    require('uiohook-napi').uIOhook.stop();
  } catch {
    // Optional dependency may be absent during development.
  }
});
