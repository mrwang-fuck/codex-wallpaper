const fs = require('node:fs');
const path = require('node:path');
function shouldApplyToURL(value) {
  try { const url = new URL(value); return url.protocol === 'app:' && url.hostname === '-' && url.pathname === '/index.html'; }
  catch { return false; }
}
function number(value, fallback, low, high) {
  const numeric = Number(value); return Number.isFinite(numeric) ? Math.min(high, Math.max(low, numeric)) : fallback;
}
function readSettings(file) {
  return validateSettings(JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/,'')));
}
function validateSettings(settings) {
  if (settings.enabled !== true) return { enabled: false };
  if (typeof settings.imagePath !== 'string' || !path.isAbsolute(settings.imagePath)) throw new Error('An absolute image path is required');
  if (fs.statSync(settings.imagePath).size > 20 * 1024 * 1024) throw new Error('Wallpaper image is larger than 20 MiB');
  const bytes = fs.readFileSync(settings.imagePath);
  if (bytes.length > 20 * 1024 * 1024) throw new Error('Wallpaper image is larger than 20 MiB');
  let mime;
  if (bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) mime = 'image/png';
  else if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) mime = 'image/jpeg';
  else if (bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') mime = 'image/webp';
  else throw new Error('Wallpaper must contain PNG, JPEG or WebP image bytes');
  return { enabled: true, scope: settings.scope === 'window' ? 'window' : 'chat', dataUri: `data:${mime};base64,${bytes.toString('base64')}`, brightness: number(settings.brightness, 1, .1, 2), blur: number(settings.blur, 0, 0, 30), tint: number(settings.tint, .22, 0, .9) };
}
function buildStylesheet(settings) {
  if (!settings.enabled) return '';
  const main = '#root main[class*="MainContentSurface"]';
  if (settings.scope === 'window') return `
    html{background:transparent!important}
    body{position:relative!important;isolation:isolate!important;background:transparent!important}
    body::before{content:'';position:fixed;inset:-40px;z-index:-2;pointer-events:none;background-image:url("${settings.dataUri}");background-size:cover;background-position:center;filter:blur(${settings.blur}px) brightness(${settings.brightness})}
    body::after{content:'';position:fixed;inset:0;z-index:-1;pointer-events:none;background-color:color-mix(in srgb,var(--color-surface,#fff) ${settings.tint * 100}%,transparent)!important}
    #root{position:relative!important;isolation:isolate!important;background:transparent!important}
    #root [class*="_Layout_"],#root [class*="_PageSurfaceLayout_"],#root [class*="_WorkspaceContent_"],${main}{background:transparent!important}
    ${main}::before,${main}::after{content:none!important;background-image:none!important}
    #root [class*="_ApplicationMenuTopBar_"]{background-color:color-mix(in srgb,var(--color-surface,#fff) 18%,transparent)!important;backdrop-filter:blur(8px)}
    #root .sidebar-navigation{background-color:color-mix(in srgb,var(--color-surface,#fff) 34%,transparent)!important;backdrop-filter:blur(12px)}
    #root .sidebar-navigation .sidebar-navigation{background:transparent!important;backdrop-filter:none!important}
    #root .bg-surface{background-color:transparent!important}
    #root [class*="_MainContentTopFade_"],#root .from-surface{background:none!important}
    #root [class*="_ComposerLayoutRoot_"]{background:transparent!important}
    #root [data-composer-body],#root [class*="_ComposerLayoutBody_"]{background-color:color-mix(in srgb,var(--color-surface,#fff) 68%,transparent)!important;backdrop-filter:blur(18px) saturate(1.15)!important}
    #root [class~="bg-surface-elevated-secondary"],#root [class~="bg-surface-elevated-primary"],#root [class~="bg-surface-elevated-secondary/50"]{background-color:color-mix(in srgb,var(--color-surface,#fff) 62%,transparent)!important;backdrop-filter:blur(12px)}
    #root [class~="group/summary-panel"]{background-color:color-mix(in srgb,var(--color-surface,#fff) 64%,transparent)!important;backdrop-filter:blur(16px)}
    #root [class~="group/summary-panel"] header{background-color:color-mix(in srgb,var(--color-surface,#fff) 20%,transparent)!important}
    #root [class~="group/summary-panel"] header::before{background:transparent!important}
    [role="menu"],[role="dialog"],[role="listbox"]{background-color:color-mix(in srgb,var(--color-surface,#fff) 88%,transparent)!important;backdrop-filter:blur(18px)}
  `;
  return `
    ${main}{position:relative!important;isolation:isolate!important;background-color:transparent!important}
    ${main}::before{content:'';position:absolute;inset:-40px;z-index:-1;pointer-events:none;background-image:url("${settings.dataUri}");background-size:cover;background-position:center;filter:blur(${settings.blur}px) brightness(${settings.brightness})}
    ${main}::after{content:'';position:absolute;inset:0;z-index:-1;pointer-events:none;background-color:color-mix(in srgb,var(--color-surface,#fff) ${settings.tint * 100}%,transparent)!important}
    ${main} .bg-surface{background-color:transparent!important}
    ${main} [data-composer-body],${main} [class*="_ComposerLayoutBody_"]{background-color:color-mix(in srgb,var(--color-surface,#fff) 45%,transparent)!important;backdrop-filter:blur(18px) saturate(1.15)!important}
    ${main} [role="dialog"],${main} [role="menu"],${main} [role="listbox"]{background-color:var(--color-surface,#fff)!important}
  `;
}
module.exports={shouldApplyToURL,readSettings,validateSettings,buildStylesheet};
