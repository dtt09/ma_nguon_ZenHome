import mqtt, { MqttClient, IClientOptions } from 'mqtt';

// ==========================================
// KẾT NỐI MQTT HIVEMQ CLOUD (TLS PORT 8883)
// ==========================================
const mqttUrl = process.env.MQTT_URL || 'mqtts://e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud:8883';
const mqttOptions: IClientOptions = {
    rejectUnauthorized: false
};

if (process.env.MQTT_USERNAME) mqttOptions.username = process.env.MQTT_USERNAME;
if (process.env.MQTT_PASSWORD) mqttOptions.password = process.env.MQTT_PASSWORD;

export const client: MqttClient = mqtt.connect(mqttUrl, mqttOptions);

export default client;
