const mqtt = require('mqtt');

// ==========================================
// KẾT NỐI MQTT HIVEMQ CLOUD (TLS PORT 8883)
// ==========================================
const mqttUrl = process.env.MQTT_URL || 'mqtts://e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud:8883';
const mqttOptions = {
    rejectUnauthorized: false
};
if (process.env.MQTT_USERNAME) mqttOptions.username = process.env.MQTT_USERNAME;
if (process.env.MQTT_PASSWORD) mqttOptions.password = process.env.MQTT_PASSWORD;

const client = mqtt.connect(mqttUrl, mqttOptions);

module.exports = client;
