const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function verifyFirmwareRelease(binary, signatureHex) {
  if (typeof signatureHex !== 'string' || !/^(?:[a-f\d]{2})+$/i.test(signatureHex)) {
    throw new Error('Missing or malformed firmware signature');
  }
  const header = fs.readFileSync(path.join(__dirname, '../esp32_1/include/firmware_signer_pubkey.h'), 'utf8');
  const pem = Array.from(header.matchAll(/"([^"]+)\\n"/g), match => match[1]).join('\n');
  if (!crypto.verify('sha256', binary, pem, Buffer.from(signatureHex, 'hex'))) {
    throw new Error('Firmware signature does not match the public key trusted by the hub');
  }
  return crypto.createHash('sha256').update(binary).digest('hex').toUpperCase();
}

if (require.main === module) {
  const [bin, manifest] = process.argv.slice(2);
  const data = fs.readFileSync(bin);
  const meta = JSON.parse(fs.readFileSync(manifest, 'utf8'));
  if (verifyFirmwareRelease(data, meta.sig) !== String(meta.sha256).toUpperCase() ||
      data.length !== (meta.fileSizeBytes ?? meta.size)) throw new Error('Firmware metadata differs from artifact');
}
module.exports = { verifyFirmwareRelease };
