# RMADA Stage 3 — Mobile VPN Setup Guide

## Overview

This guide covers how to connect mobile devices (iOS, Android) to RMADA using either:
- **Lightway** (primary, if available)
- **WireGuard** (fallback, widely supported)
- **Linux Gateway** (advanced, forward all mobile traffic through Linux router)

---

## Quick Start: WireGuard Mobile (Recommended)

### iOS Setup (WireGuard App)

#### 1. Install WireGuard

```
iOS App Store → Search "WireGuard" → Install
```

#### 2. Get Configuration

```bash
# From your server:
curl -k https://YOUR_SERVER_IP:8443/api/wireguard-config \
  -H "Content-Type: application/json" \
  -d '{"device":"iphone"}' > rmada-ios.conf
```

#### 3. Generate QR Code

```bash
# Convert config to QR code
qrencode -t utf8 < rmada-ios.conf

# Or use online tool:
# https://www.qr-code-generator.com/
```

#### 4. Import to iPhone

- Open WireGuard app
- Tap "+" button
- Select "Create from QR code"
- Scan QR code
- Tap "Save"
- Toggle "Activate" to connect

#### 5. Verify Connection

```
Settings → VPN → Check if connected
Look for IP in 10.1.0.0/24 range
```

### Android Setup (WireGuard App)

#### 1. Install WireGuard

```
Google Play Store → Search "WireGuard" → Install
```

#### 2. Get Configuration

```bash
# From your server:
curl -k https://YOUR_SERVER_IP:8443/api/wireguard-config \
  -H "Content-Type: application/json" \
  -d '{"device":"android"}' > rmada-android.conf
```

#### 3. Import Config

**Option A: QR Code**
```bash
qrencode -t utf8 < rmada-android.conf
# Scan with WireGuard app
```

**Option B: Manual Import**
- Open WireGuard app
- Tap "+" button
- Select "Import config file"
- Choose `rmada-android.conf`
- Tap "Save"

#### 4. Connect

- Toggle the connection ON
- Accept VPN permission prompt
- Check notification: "VPN is active"

#### 5. Verify

```
Settings → Network → Mobile networks → Check VPN
Should show 10.1.0.x IP address
```

---

## Lightway Mobile (Advanced)

### iOS Lightway Setup

#### Prerequisites

- Lightway iOS SDK (if available)
- Alternative: Use WireGuard instead (recommended)

#### Install

```
App Store → Search "Lightway VPN" (if available)
Or build from source: https://github.com/ExpressVPN/lightway-core
```

#### Configure

```
1. Open Lightway app
2. Tap "Add Profile"
3. Enter:
   - Server: YOUR_SERVER_IP:1024
   - Username: your-phone
   - Password: (from server-generated key)
4. Tap "Save"
5. Tap "Connect"
```

### Android Lightway Setup

Similar to iOS, but using Android Lightway app:

```
Google Play Store → "Lightway VPN"
```

---

## Advanced: Linux Gateway

### Use Case

Forward all mobile traffic through a Linux machine connected to RMADA:

```
Mobile Device (iOS/Android)
    ↓
Linux Gateway (via Wi-Fi)
    ↓
Lightway/WireGuard VPN
    ↓
RMADA Server
```

### Setup Linux Gateway

#### 1. Install WireGuard on Linux

```bash
sudo apt-get install wireguard wireguard-tools

# Generate keys
wg genkey | tee privatekey | wg pubkey > publickey
```

#### 2. Create WireGuard Interface

```bash
# Edit /etc/wireguard/rmada.conf
sudo nano /etc/wireguard/rmada.conf
```

```ini
[Interface]
PrivateKey = <your_private_key>
Address = 10.1.0.5/32
ListenPort = 51820
DNS = 8.8.8.8

[Peer]
PublicKey = <server_public_key>
Endpoint = YOUR_SERVER_IP:51820
AllowedIPs = 10.1.0.0/24
PersistentKeepalive = 25
```

#### 3. Enable IP Forwarding

```bash
sudo sysctl -w net.ipv4.ip_forward=1

# Make permanent
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

#### 4. Configure NAT

```bash
# Enable NAT for mobile devices
sudo iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
sudo iptables -A FORWARD -i wlan0 -o wg0 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

#### 5. Start WireGuard

```bash
sudo systemctl enable wg-quick@rmada
sudo systemctl start wg-quick@rmada

# Check status
sudo wg show
```

#### 6. Enable Wi-Fi Hotspot on Linux

```bash
# Use hostapd for Wi-Fi hotspot
sudo apt-get install hostapd dnsmasq

# Configure hostapd
sudo nano /etc/hostapd/hostapd.conf
```

```ini
interface=wlan0
ssid=RMADA-Gateway
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=SecurePassword123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
wpa_group_rekey=86400
ieee80211n=1
```

#### 7. Configure DHCP for Hotspot

```bash
# Edit dnsmasq config
sudo nano /etc/dnsmasq.conf
```

```ini
interface=wlan0
dhcp-range=192.168.100.2,192.168.100.100,12h
dhcp-option=option:router,192.168.100.1
server=8.8.8.8
```

#### 8. Set Up Bridge (Optional)

```bash
# Create bridge for direct forwarding
sudo brctl addbr br0
sudo brctl addif br0 wlan0
sudo brctl addif br0 wg0

sudo ip addr add 192.168.100.1/24 dev br0
sudo ip link set br0 up
```

### Connect Mobile via Gateway

#### iOS

```
1. Open Settings
2. Wi-Fi
3. Select "RMADA-Gateway"
4. Enter password: SecurePassword123
5. Done! All traffic goes through Linux → VPN
```

#### Android

```
1. Settings → Wi-Fi
2. Tap "+" to add network
3. Network name: RMADA-Gateway
4. Security: WPA2-PSK
5. Password: SecurePassword123
6. Connect
```

#### Verify

From mobile:
```bash
# SSH into Linux gateway
ssh gateway-ip

# Check connected clients
sudo arp-scan --localnet

# Verify VPN tunnel
ping 10.1.0.1
```

---

## Configuration Templates

### WireGuard Config Template (QR Code)

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = <DEVICE_IP>/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <SERVER_PUBLIC_IP>:51820
AllowedIPs = 10.1.0.0/24
PersistentKeepalive = 25
```

### Generate QR Code

```bash
# Install qrencode
apt-get install qrencode

# Create QR code
qrencode -t png -o rmada-mobile.png < config.conf

# Or display in terminal
qrencode -t utf8 < config.conf
```

---

## Troubleshooting Mobile Connections

### iOS: VPN Not Connecting

```
1. Check Internet connection (Wi-Fi/LTE)
2. Verify server IP is correct
3. Try removing and re-adding profile
4. Check VPN permission in Settings → Privacy → VPN
5. Restart iPhone
```

### Android: Connection Drops

```
1. Open WireGuard app
2. Tap "Settings"
3. Enable "Restore on Boot"
4. Enable "Auto Reconnect"
5. Adjust "KeepAlive" to 15-25 seconds
```

### Can't Access Resources

```
# Check if split tunneling is enabled
# Disable if you want all traffic through VPN

iOS: Settings → VPN → <Profile> → "Use VPN" should be ON
Android: WireGuard → <Tunnel> → Settings → "Always On" toggle
```

### Slow Connection on Mobile

```
# Switch to 5G/LTE (from Wi-Fi) to test
# Lower KeepAlive value in config
# Request smaller packet size (MTU)

# Get new config with MTU=1200
curl https://server/api/mobile-config?mtu=1200
```

---

## Security Best Practices

### Mobile-Specific

✅ Use strong password for gateway hotspot  
✅ Enable "Always On" VPN for automatic reconnect  
✅ Pin server certificate (if possible)  
✅ Regularly update VPN app  
✅ Use VPN kill switch (some apps support this)  
✅ Rotate credentials every 90 days  
✅ Don't share configs outside organization  

### Gateway Best Practices

✅ Use strong Wi-Fi password  
✅ Change default SSH port  
✅ Use firewall rules  
✅ Monitor connected devices  
✅ Keep Linux updated  
✅ Use certificate-based auth for SSH  

---

## Testing

### Test Mobile Connection

#### From Mobile Device

```bash
# SSH into a server on RMADA network
ssh user@10.1.0.1

# Ping server
ping 10.1.0.1

# Speed test
curl -O https://speed.test.example.com/100mb.bin
```

#### From Server

```bash
# See connected mobile clients
curl -k https://localhost:8443/api/connected-devices | jq '.[] | select(.type=="mobile")'

# Check bandwidth usage by device
curl -k https://localhost:8443/api/bandwidth-by-device | jq '.[] | select(.device_type=="mobile")'
```

### Monitor Gateway (Linux)

```bash
# Watch connected devices
watch 'sudo arp-scan --localnet | grep RMADA'

# Monitor bandwidth
iftop -i br0

# Check NAT rules
sudo iptables -L -t nat -n -v
```

---

## Advanced: VPN Kill Switch

Some VPN apps support "kill switch" to block traffic if VPN drops:

### WireGuard Kill Switch

```bash
# Linux (using iptables)
# Block all traffic except VPN interface
sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -A INPUT -i wg0 -j ACCEPT
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o wg0 -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT
```

### iOS

- WireGuard app → Settings → Enable "VPN Kill Switch"
- Alternative: iOS native " Always On" VPN

### Android

- WireGuard app → Settings → Enable "Kill Switch"
- Alternative: Android Enterprise / Work Profile

---

## Integration with Dashboard

### Access Dashboard from Mobile

```
iOS/Android Browser:
https://YOUR_SERVER_IP:8443

Or if using gateway:
https://10.1.0.1:8443
```

### Mobile-Optimized Dashboard

Operação.html and Dispositivo.html are responsive and work on mobile:

```
- Tap devices to view telemetry
- Charts auto-scale for small screens
- Touch-friendly controls
```

---

## Reference

### Supported Protocols

| Protocol | iOS | Android | Desktop | Notes |
|----------|-----|---------|---------|-------|
| WireGuard | ✅ | ✅ | ✅ | Best mobile support |
| Lightway | ⚠️ | ⚠️ | ✅ | Check availability |
| OpenVPN | ✅ | ✅ | ✅ | Not used in RMADA |
| IPSec | ✅ | ✅ | ✅ | Not used in RMADA |

### Apps

- **iOS WireGuard**: https://apps.apple.com/us/app/wireguard/id1451685025
- **Android WireGuard**: https://play.google.com/store/apps/details?id=com.wireguard.android
- **Lightway**: Check App Store/Play Store (ExpressVPN)

### Documentation

- **WireGuard Mobile**: https://www.wireguard.com/install/
- **Lightway**: https://www.expressvpn.com/lightway
- **Hotspot Guide**: https://ubuntu.com/tutorials/set-up-a-wi-fi-hotspot

---

**Status**: Mobile VPN ready (WireGuard primary + Lightway alternative + Linux gateway)  
**Next**: Run end-to-end tests in test-stage3-e2e.sh
