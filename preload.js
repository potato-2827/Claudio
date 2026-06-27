const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  load: () => ipcRenderer.invoke('load'),
  save: (data) => ipcRenderer.invoke('save', data),
  setAlwaysOnTop: (on) => ipcRenderer.invoke('set-always-on-top', on)
});
