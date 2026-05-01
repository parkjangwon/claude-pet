const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('claudePet', {
  state: () => ipcRenderer.invoke('state'),
  moveBy: (dx) => ipcRenderer.send('move-by', dx),
  feed: () => ipcRenderer.send('feed'),
  setScale: (index) => ipcRenderer.send('set-scale', index),
  incrementTyping: () => ipcRenderer.send('typing'),
  setHunger: (value) => ipcRenderer.send('hunger', value),
  setHideTaskbar: (hide) => ipcRenderer.send('hide-taskbar', hide),
  quit: () => ipcRenderer.send('quit'),
  onTypingCount: (fn) => ipcRenderer.on('typing-count', (_event, value) => fn(value)),
  onSettings: (fn) => ipcRenderer.on('settings', (_event, value) => fn(value)),
  onClaudeCpu: (fn) => ipcRenderer.on('claude-cpu', (_event, value) => fn(value)),
  onClaudeRunning: (fn) => ipcRenderer.on('claude-running', (_event, value) => fn(value)),
  onKeyboardHookUnavailable: (fn) => ipcRenderer.on('keyboard-hook-unavailable', () => fn())
});
