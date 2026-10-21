const path = require('node:path');
const {readRaw,updateSettings} = require('./settings-store.cjs');
const root = path.resolve(__dirname, '..');
async function main() {
  const args = process.argv.slice(2);
  const change = {};
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--image': if (!args[i+1]) throw new Error('缺少图片路径'); change.imagePath = path.resolve(args[++i]); change.enabled = true; break;
      case '--scope': change.scope = args[++i]; break;
      case '--tint': change.tint = Number(args[++i]); break;
      case '--transparency': change.transparency = Number(args[++i]); break;
      case '--brightness': change.brightness = Number(args[++i]); break;
      case '--blur': change.blur = Number(args[++i]); break;
      case '--off': change.enabled = false; break;
      case '--on': change.enabled = true; break;
      case '--status': console.log(JSON.stringify(readRaw(root), null, 2)); return;
      default: throw new Error(`Unknown option: ${args[i]}`);
    }
  }
  const settings = await updateSettings(root,change);
  console.log(JSON.stringify({ enabled: settings.enabled, imagePath: settings.imagePath, brightness: settings.brightness, blur: settings.blur, tint: settings.tint, scope: settings.scope || 'chat' }));
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
