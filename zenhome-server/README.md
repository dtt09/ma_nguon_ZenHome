# ZenHome Smart IoT

ZenHome is an IoT Smart Home automation platform and microcontroller management dashboard. Migrated from the ZenHome Flutter mobile client and ESP32 firmware project into a high-performance, responsive React web application.

## Key Features

- **Dashboard & Room Controls**:
  - Live control of smart lighting, ceiling fans, inverter air conditioners, water heaters, and outdoor lighting.
  - Multi-room filtering (Living Room, Bedroom, Kitchen, Bathroom, Outdoor).
  - Tactile sliders for dimmers, fan speed levels, and temperature setpoints.
  - Auto-off timers with countdown indicators and automatic relay shutoff.
  - Master "Turn All ON" and "Turn All OFF" quick switches.

- **Smart Scenes & Automation**:
  - Pre-configured scenes: *Leave Home*, *Arrive Home*, *Sleep Mode*, *Movie Night*, *Party Ambiance*.
  - Custom scene creator with color scheme picker and device action configuration.
  - Automated schedule overview for daytime/nighttime routines.

- **ESP32 Microcontroller & MQTT Telemetry**:
  - Real-time ESP32 hardware status (Online/Offline, MAC, IP, Wi-Fi RSSI in dBm, status LED GPIO 2).
  - Virtual Hardware Simulator: Adjust DHT11/22 indoor temperature and humidity telemetry in real-time.
  - Live MQTT stream monitor (Topic publish/subscribe traffic viewer) with custom packet publisher.
  - Complete GPIO pin mapping table matching the physical ESP32 relay and sensor schematics.
  - Wi-Fi AP provisioning interface (simulating 192.168.4.1 LittleFS flashing).

- **Activity & Alerts**:
  - Audit trail of device state toggles, timer completions, and threshold alerts.
  - Exportable STEM Engineering Report.

- **Localization & Theming**:
  - Full English (EN) and Vietnamese (VI) bilingual translation.
  - Dark and Light mode support with automatic system preference detection.

## Development

```bash
npm install
npm run dev
```

Built with React 19, TypeScript, Tailwind CSS, and Vite.
