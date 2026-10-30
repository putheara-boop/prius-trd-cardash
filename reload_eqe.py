import subprocess

ssh_cmd = [
    'ssh',
    '-i', r'C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_trd_key',
    '-p', '22222',
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'HostKeyAlgorithms=+ssh-rsa',
    '-o', 'PubkeyAcceptedKeyTypes=+ssh-rsa',
    'root@127.0.0.1',
    "echo \"eqe.load('TRD Rock')\" | /usr/bin/eqe core"
]
p = subprocess.Popen(ssh_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
out, err = p.communicate()
print("STDOUT:", out.decode('utf-8', errors='replace'))
print("STDERR:", err.decode('utf-8', errors='replace'))
