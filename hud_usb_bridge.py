import socket
import struct
import plistlib
import threading
import select
import time

def receive(s, n):
    b = b''
    while len(b) < n:
        q = s.recv(n - len(b))
        if not q:
            raise EOFError()
        b += q
    return b

def request(s, p, t):
    d = plistlib.dumps(p)
    s.sendall(struct.pack('<IIII', 16 + len(d), 1, 8, t) + d)
    n, _, _, _ = struct.unpack('<IIII', receive(s, 16))
    return plistlib.loads(receive(s, n - 16))

def handle_client(c, target_port):
    s = None
    try:
        s = socket.create_connection(('127.0.0.1', 27015), 5)
        r = request(s, {'MessageType': 'ListDevices', 'ClientVersionString': 'TRD HUD', 'ProgName': 'TRD HUD', 'kLibUSBMuxVersion': 3}, 1)
        devices = [d for d in r.get('DeviceList', []) if d.get('Properties', {}).get('ConnectionType') == 'USB']
        if not devices:
            return
        dev_id = devices[0]['DeviceID']
        r = request(s, {'MessageType': 'Connect', 'DeviceID': dev_id, 'PortNumber': socket.htons(target_port)}, 2)
        if r.get('Number') != 0:
            return
        s.settimeout(None)
        while True:
            ready, _, _ = select.select([c, s], [], [], 60)
            if not ready:
                break
            for src in ready:
                data = src.recv(65536)
                if not data:
                    return
                (s if src is c else c).sendall(data)
    except Exception:
        pass
    finally:
        try:
            c.close()
        except Exception:
            pass
        if s:
            try:
                s.close()
            except Exception:
                pass

def serve_bridge(listen_port, ipad_port):
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(('0.0.0.0', listen_port))
    srv.listen(32)
    while True:
        c, _ = srv.accept()
        threading.Thread(target=handle_client, args=(c, ipad_port), daemon=True).start()

if __name__ == '__main__':
    for p in (80, 8080, 8088):
        try:
            threading.Thread(target=serve_bridge, args=(p, p), daemon=True).start()
        except Exception:
            pass
    print('HUD USB Bridge listening on 0.0.0.0:80, 8080, 8088 -> iPad')
    while True:
        time.sleep(3600)
