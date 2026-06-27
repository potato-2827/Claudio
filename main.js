const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');

const DATA = path.join(__dirname, 'tareas.json');
const BACKUPS = path.join(__dirname, 'backups');
let lastBackup = 0;

function readState() {
  try { return JSON.parse(fs.readFileSync(DATA, 'utf8')); }
  catch (e) { return {}; }
}

function writeState(data) {
  const json = JSON.stringify(data);
  const tmp = DATA + '.tmp';
  fs.writeFileSync(tmp, json, 'utf8');
  fs.renameSync(tmp, DATA);              // escritura atomica
  const now = Date.now();
  if (now - lastBackup >= 5 * 60 * 1000) {  // copia periodica (cada 5 min)
    lastBackup = now;
    try {
      fs.mkdirSync(BACKUPS, { recursive: true });
      const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
      fs.writeFileSync(path.join(BACKUPS, `tareas-${stamp}.json`), json, 'utf8');
      const files = fs.readdirSync(BACKUPS)
        .filter(f => f.startsWith('tareas-') && f.endsWith('.json')).sort();
      while (files.length > 40) { fs.unlinkSync(path.join(BACKUPS, files.shift())); }
    } catch (e) {}
  }
  return true;
}

let win;
function createWindow() {
  win = new BrowserWindow({
    width: 460,
    height: 820,
    minWidth: 360,     // <-- TOPE DURO: Windows no deja achicar mas (lo maneja la app desde adentro)
    minHeight: 420,
    title: 'Mis Tareas',
    icon: path.join(__dirname, 'icono.ico'),
    backgroundColor: '#16131f',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });
  win.removeMenu();
  win.loadFile(path.join(__dirname, 'app', 'index.html'));
}

ipcMain.handle('load', () => readState());
ipcMain.handle('save', (e, data) => writeState(data));
ipcMain.handle('set-always-on-top', (e, on) => { if (win) win.setAlwaysOnTop(!!on); return !!on; });

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });
  app.whenReady().then(() => {
    createWindow();
    app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
  });
  app.on('window-all-closed', () => { app.quit(); });
}
