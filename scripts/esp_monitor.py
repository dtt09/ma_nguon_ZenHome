import serial
import serial.tools.list_ports
import time
import sys
from datetime import datetime

# Ensure UTF-8 output on Windows console
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

def find_esp_port():
    ports = serial.tools.list_ports.comports()
    for p in ports:
        desc = (p.description or '').lower()
        hwid = (p.hwid or '').lower()
        if 'ch340' in desc or 'cp210' in desc or 'uart' in desc or '1a86' in hwid or '10c4' in hwid:
            return p.device
    for p in ports:
        if p.device.upper() == 'COM3':
            return p.device
    if ports:
        return ports[0].device
    return 'COM3'

baud = 115200

print("--- [ZENHOME ESP32 LIVE MONITOR] ---", flush=True)

while True:
    port = find_esp_port()
    try:
        ser = serial.Serial(port, baud, timeout=0.5)
        ser.dtr = False
        ser.rts = False
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Đã kết nối vào {port} ({baud} baud). Đang đọc log...", flush=True)
        
        while True:
            raw = ser.readline()
            if raw:
                try:
                    text = raw.decode('utf-8', errors='replace').rstrip()
                except Exception:
                    text = raw.decode('latin1', errors='replace').rstrip()
                if text:
                    now = datetime.now().strftime('%H:%M:%S')
                    print(f"[{now}] {text}", flush=True)
            time.sleep(0.01)
    except KeyboardInterrupt:
        print("\nĐã dừng theo dõi log.", flush=True)
        break
    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Chờ kết nối cổng ({e}). Thử lại sau 2s...", flush=True)
        time.sleep(2)
