const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

function verifyApkRelease(apk) {
  const pinned = fs.readFileSync(path.join(__dirname, '../zenhome_app/android/release-cert.sha256'), 'utf8').trim();
  const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT ||
    (process.platform === 'win32' ? path.join(os.homedir(), 'AppData/Local/Android/Sdk')
      : process.platform === 'darwin' ? path.join(os.homedir(), 'Library/Android/sdk') : path.join(os.homedir(), 'Android/Sdk'));
  const dir = path.join(sdk, 'build-tools');
  const jar = fs.readdirSync(dir).sort((a,b) => b.localeCompare(a, undefined, {numeric:true}))
    .map(v => path.join(dir, v, 'lib/apksigner.jar')).find(file => fs.existsSync(file));
  if (!jar) throw new Error('Android SDK build-tools with apksigner required');
  const result = execFileSync('java', ['-jar',jar,'verify','--print-certs',apk], {encoding:'utf8'});
  const signers = [...result.matchAll(/^Signer #\d+ certificate SHA-256 digest:\s*([a-f0-9]{64})\s*$/gmi)];
  if (signers.length !== 1 || signers[0][1].toLowerCase() !== pinned.toLowerCase()) {
    throw new Error('APK signature does not match the ZenHome release certificate');
  }
  const aapt = path.resolve(path.dirname(jar), '..', process.platform === 'win32' ? 'aapt.exe' : 'aapt');
  const entries = execFileSync(aapt, ['list', apk], { encoding: 'utf8' }).split(/\r?\n/);
  if (entries.some(entry => /^assets\/flutter_assets\/(?:.*\/)?\.env(?:\.[^/]+)?$/i.test(entry))) {
    throw new Error('APK includes a Flutter environment file. Clean the Android build outputs and rebuild.');
  }
}
if (require.main === module) verifyApkRelease(process.argv[2]);
module.exports = {verifyApkRelease};
