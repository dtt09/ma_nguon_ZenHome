import { db } from '../server/core/firebase';
import { getCurrentServerConfig } from '../server/core/networkSync';

async function updateEsp32Ota() {
  const config = getCurrentServerConfig();
  const baseUrl = config.serverBaseUrl || 'http://192.168.1.10:5000';
  const directUrl = `${baseUrl}/public/firmware/esp32/firmware.bin`;

  const meta = {
    version: '1.7.9',
    buildNumber: 179,
    fileName: 'firmware.bin',
    fileSizeBytes: 1341200,
    sha256: 'C46D7192794D1F1AB9BA1EA88628AE611B33D6BAA5F6B16EC289BBECDFC4669D',
    directUrl,
    lastDeployedAt: new Date().toISOString(),
    supportedHardware: 'ESP32 (min_spiffs.csv dual OTA)',
  };

  if (db) {
    await db.collection('system_config').doc('esp32_firmware').set(meta, { merge: true });
    console.log('[FIRESTORE] Successfully updated system_config/esp32_firmware to v1.7.9');
  } else {
    console.log('[FIRESTORE] DB not connected.');
  }
  process.exit(0);
}

updateEsp32Ota().catch(err => {
  console.error(err);
  process.exit(1);
});
