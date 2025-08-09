const { app, BrowserWindow } = require('electron');

function createWindow() {
  const win = new BrowserWindow({ width: 900, height: 600 });
  win.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(`
    <!doctype html>
    <html lang="pl"><meta charset="utf-8" />
    <title>SafeSpac</title>
    <style>body{font-family:system-ui,Arial;margin:2rem} code{background:#eee;padding:.2rem .4rem;border-radius:4px}</style>
    <h1>SafeSpac Desktop</h1>
    <p>Połącz się przez WireGuard, następnie otwórz: <code>http://portal.safe.lan</code>.</p>
    <p>Publiczny front (rejestracja/zaproszenia) dostępny pod adresem publicznym serwera.</p>
    </html>
  `));
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
