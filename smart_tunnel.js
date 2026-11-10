const net = require("net");

function htons(port) {
  return ((port & 0xff) << 8) | ((port >> 8) & 0xff);
}

function makeUsbmuxPacket(obj, tag = 1) {
  let plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
`;
  for (const [k, v] of Object.entries(obj)) {
    plist += `  <key>${k}</key>\n`;
    if (typeof v === "string") plist += `  <string>${v}</string>\n`;
    else if (typeof v === "number") plist += `  <integer>${v}</integer>\n`;
  }
  plist += `</dict>
</plist>`;
  const body = Buffer.from(plist, "utf8");
  const hdr = Buffer.alloc(16);
  hdr.writeUInt32LE(16 + body.length, 0);
  hdr.writeUInt32LE(1, 4);
  hdr.writeUInt32LE(8, 8);
  hdr.writeUInt32LE(tag, 12);
  return Buffer.concat([hdr, body]);
}

let currentDeviceId = 4;

// Monitor device events dynamically
function monitorUsbmux() {
  const mon = net.createConnection({ port: 27015, host: "127.0.0.1" }, () => {
    mon.write(makeUsbmuxPacket({ MessageType: "Listen" }, 1));
  });
  mon.on("data", (data) => {
    const str = data.toString();
    const match = str.match(/<key>DeviceID<\/key>\s*<integer>(\d+)<\/integer>/);
    if (match && match[1]) {
      currentDeviceId = parseInt(match[1], 10);
      console.log(`[SmartTunnel] Active iOS DeviceID: ${currentDeviceId}`);
    }
  });
  mon.on("error", () => setTimeout(monitorUsbmux, 2000));
  mon.on("close", () => setTimeout(monitorUsbmux, 2000));
}
monitorUsbmux();

const server = net.createServer((clientSocket) => {
  const devId = currentDeviceId;
  const usbmux = net.createConnection({ port: 27015, host: "127.0.0.1" }, () => {
    usbmux.write(makeUsbmuxPacket({
      MessageType: "Connect",
      DeviceID: devId,
      PortNumber: htons(22)
    }, 2));
  });

  let handshook = false;
  usbmux.on("data", (data) => {
    if (!handshook) {
      const len = data.readUInt32LE(0);
      handshook = true;
      if (data.length > len) {
        clientSocket.write(data.slice(len));
      }
      clientSocket.pipe(usbmux);
      usbmux.pipe(clientSocket);
    }
  });

  usbmux.on("error", () => clientSocket.destroy());
  clientSocket.on("error", () => usbmux.destroy());
});

server.listen(22222, "127.0.0.1", () => {
  console.log("SmartTunnel listening on 127.0.0.1:22222");
});
