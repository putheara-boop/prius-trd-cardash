import sys
import subprocess

def run_ssh(cmd):
    ssh_cmd = [
        'ssh',
        '-i', r'C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_trd_key',
        '-p', '22222',
        '-o', 'StrictHostKeyChecking=no',
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

def ssh_output(cmd):
    ssh_cmd = [
        'ssh',
        '-i', r'C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_trd_key',
        '-p', '22222',
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'HostKeyAlgorithms=+ssh-rsa',
        '-o', 'PubkeyAcceptedKeyTypes=+ssh-rsa',
        '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa',
        'root@127.0.0.1',
        cmd
    ]
    res = subprocess.run(ssh_cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='replace'), res.stderr.decode('utf-8', errors='replace'), res.returncode

if __name__ == '__main__':
    if len(sys.argv) > 1:
        cmd = ' '.join(sys.argv[1:])
        sys.exit(run_ssh(cmd))
