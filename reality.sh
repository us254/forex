#!/bin/bash
# Update system packages
sudo apt update
# Upgrade system packages
sudo apt upgrade -y
# Install ufw firewall
sudo apt install ufw -y
# Enable ufw firewall
sudo ufw enable
# Allow 443/tcp through the firewall
sudo ufw allow 443/tcp
# Reload firewall
sudo ufw reload
# Delete rule allowing 22/tcp
sudo ufw delete allow 22/tcp
# Add configuration lines to sysctl.conf
echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf
# Apply sysctl changes
sudo sysctl -p
# Change SSH port
sudo sed -i 's/#Port 22/Port 3345/' /etc/ssh/sshd_config
# Restart SSH service
sudo systemctl restart sshd
# Allow new SSH port through firewall
sudo ufw allow 3345/tcp
# Reload firewall
sudo ufw reload
# Install Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

# Change directory to Xray's directory
( 
cd /usr/local/share/xray/ || exit
# Remove old geosite.dat and geoip.dat files
sudo rm -f geosite.dat
sudo rm -f geoip.dat
# Download new geosite.dat and geoip.dat files
sudo wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/202310212207/geosite.dat
sudo wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/202310212207/geoip.dat
# Download ir.dat file
sudo wget https://github.com/us254/geoip/releases/download/v2.6.9/ir.dat
)

# Open the Xray service configuration file and add the environment variable
sudo bash -c 'echo Environment="XRAY_BUF_SPLICE=enable" >> /etc/systemd/system/xray.service'

# Reload the systemd manager configuration
sudo systemctl daemon-reload

# Restart the Xray service to apply the changes
sudo systemctl restart xray.service

# Download and install Go
curl -sLo go.tar.gz "https://go.dev/dl/$(curl -sL https://golang.org/VERSION?m=text|head -1).linux-amd64.tar.gz"
rm -rf /usr/local/go
tar -C /usr/local/ -xzf go.tar.gz
rm go.tar.gz

# Set up Go environment variable
echo -e "export PATH=$PATH:/usr/local/go/bin" > /etc/profile.d/go.sh

# Check if /etc/profile.d/go.sh is readable and source it if it is
if [ -r /etc/profile.d/go.sh ]; then
    source /etc/profile.d/go.sh
else
    echo "Cannot read /etc/profile.d/go.sh" >&2
    exit 1
fi
# Verify Go installation
go version
# Install git
apt install -y git
# Clone Xray-core repository
git clone https://github.com/XTLS/Xray-core.git

# Change to Xray-core directory, perform operations, then automatically return to previous directory
(
cd Xray-core || exit
# Download Go modules for the project
go mod download
# Set Go environment variables for the build
go env -w CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOAMD64=v2
# Build the project
go build -v -o xray -trimpath -ldflags "-s -w -buildid=" ./main
)

# No need to do 'cd ..' as we are back in the original directory after the subshell

# Stop the xray service
sudo systemctl stop xray.service
# Remove the old xray executable if it exists
sudo rm -f /usr/local/bin/xray
# Copy the built xray executable to /usr/local/bin/
cp -f Xray-core/xray /usr/local/bin/
# Make the xray executable
chmod +x /usr/local/bin/xray
# Change directory to /usr/local/bin/xray and perform operations
(
cd /usr/local/bin/xray || exit
# Fetch the configuration file from the remote server
curl -o /usr/local/etc/xray/config.json https://raw.githubusercontent.com/us254/forex/main/config.json
# Generate UUID
UUID=$(./xray uuid)
# Generate keys for Xray
KEY_OUTPUT=$(./xray x25519)
PRIVATE_KEY_XRAY=$(echo $KEY_OUTPUT | awk -F 'Private key: ' '{print $2}' | awk '{print $1}')
PUBLIC_KEY_XRAY=$(echo $KEY_OUTPUT | awk -F 'Public key: ' '{print $2}' | awk '{print $1}')
# Generate short ID
SHORT_ID=$(openssl rand -hex 8)
# Generate WireGuard settings
WIREGUARD_OUTPUT=$(curl -sLo warp-reg https://github.com/badafans/warp-reg/releases/download/v1.0/main-linux-amd64 && chmod +x warp-reg && ./warp-reg && rm warp-reg)
PRIVATE_KEY_WIREGUARD=$(echo $WIREGUARD_OUTPUT | awk -F 'private_key: ' '{print $2}' | awk '{print $1}')
PUBLIC_KEY_WIREGUARD=$(echo $WIREGUARD_OUTPUT | awk -F 'public_key: ' '{print $2}' | awk '{print $1}')
IPV4_ADDRESS=$(echo $WIREGUARD_OUTPUT | awk -F 'v4: ' '{print $2}' | awk '{print $1}')
IPV6_ADDRESS=$(echo $WIREGUARD_OUTPUT | awk -F 'v6: ' '{print $2}' | awk '{print $1}')
ENDPOINT=$(echo $WIREGUARD_OUTPUT | awk -F 'endpoint: ' '{print $2}' | awk '{print $1}')
RESERVED_VALUES=$(echo $WIREGUARD_OUTPUT | awk -F 'reserved: ' '{print $2}' | awk -F 'v4: ' '{print $1}')
# Load your configuration file
CONFIG=$(cat /usr/local/etc/xray/config.json)
# Replace placeholders with actual values
CONFIG=${CONFIG//<uuid>/$UUID}
CONFIG=${CONFIG//<private_key>/$PRIVATE_KEY_XRAY}
CONFIG=${CONFIG//<public_key>/$PUBLIC_KEY_XRAY}
CONFIG=${CONFIG//<shortId>/$SHORT_ID}
CONFIG=${CONFIG//<ipv4_address>/$IPV4_ADDRESS}
CONFIG=${CONFIG//<ipv6_address>/$IPV6_ADDRESS}
CONFIG=${CONFIG//<endpoint>/$ENDPOINT}
CONFIG=${CONFIG//<reserved_values>/$RESERVED_VALUES}
# Save the updated configuration back to the file
echo "$CONFIG" > /usr/local/etc/xray/config.json
# Fetch the configuration file from the remote server
curl -o /usr/local/etc/xray/config.json https://raw.githubusercontent.com/us254/forex/main/client.json
# Load your configuration file
CONFIG=$(cat /usr/local/etc/xray/client.json)

# Assuming you have the values in the variables UUID, PUBLIC_KEY_XRAY, and SHORT_ID
# Replace placeholders with actual values
CONFIG//\$UUID/$UUID}
CONFIG=${CONFIG//\$PUBLIC_KEY_XRAY/$PUBLIC_KEY_XRAY}
CONFIG=${CONFIG//\$SHORT_ID/$SHORT_ID}

# Save the updated configuration back to the file
echo "$CONFIG" > /usr/local/etc/xray/client.json
)

