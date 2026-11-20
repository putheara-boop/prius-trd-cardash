import sys
import socket
import struct
import plistlib
import threading
import select
import subprocess

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

def forward_loop(srv):
    while True:
        try:
            c, _ = srv.accept()
        except Exception:
            break
        threading.Thread(target=handle_client, args=(c,), daemon=True).start()

def handle_client(c):
    s = None
    try:
        s = socket.create_connection(('127.0.0.1', 27015), 5)
        r = request(s, {'MessageType': 'ListDevices', 'ClientVersionString': 'TRD USB', 'ProgName': 'TRD USB', 'kLibUSBMuxVersion': 3}, 1)
        devices = [d for d in r.get('DeviceList', []) if d.get('Properties', {}).get('ConnectionType') == 'USB']
        if not devices:
            raise RuntimeError('No USB iOS device attached')
        dev_id = devices[0]['DeviceID']
        r = request(s, {'MessageType': 'Connect', 'DeviceID': dev_id, 'PortNumber': socket.htons(22)}, 2)
        if r.get('Number') != 0:
            raise RuntimeError(f'Port 22 connect failed: {r}')
        s.settimeout(None)
        while True:
            ready, _, _ = select.select([c, s], [], [], 300)
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

def start_ephemeral_tunnel():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.bind(('127.0.0.1', 0))
    port = srv.getsockname()[1]
    srv.listen(8)
    threading.Thread(target=forward_loop, args=(srv,), daemon=True).start()
    return srv, port

def run_ssh(cmd):
    srv, port = start_ephemeral_tunnel()
    try:
        ssh_cmd = [
            'ssh',
            '-i', r'C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_trd_key',
            '-p', str(port),
            '-o', 'StrictHostKeyChecking=no',
            '-o', 'UserKnownHostsFile=NUL',
            '-o', 'HostKeyAlgorithms=+ssh-rsa',
            '-o', 'PubkeyAcceptedKeyTypes=+ssh-rsa',
            '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa',
            'root@127.0.0.1',
            cmd
        ]
        res = subprocess.run(ssh_cmd, capture_output=True)
        if res.stdout:
            sys.stdout.buffer.write(res.stdout)
        if res.stderr:
            sys.stderr.buffer.write(res.stderr)
        return res.returncode
    finally:
        srv.close()

if __name__ == '__main__':
    if len(sys.argv) > 1:
        cmd = ' '.join(sys.argv[1:])
        sys.exit(run_ssh(cmd))
