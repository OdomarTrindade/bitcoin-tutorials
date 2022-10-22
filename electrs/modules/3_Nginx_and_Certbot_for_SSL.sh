# A script to set up the Electrum Server in Rust on the RaspiBlitz to connect over SSL to Eclair and Electrum wallet
# Sets up the automatic start of nginx and certbot

# To download and run:
# $ wget https://raw.githubusercontent.com/openoms/bitcoin-tutorials/master/electrs/3_Nginx_and_Certbot_for_SSL.sh && bash 3_Nginx_and_Certbot_for_SSL.sh

# For the certificate to be obtained successfully a dynamic DNS and port forwarding is needed
# Need to forward port 80 to the IP of your RaspiBlitz for certbot
# Forward port 50002 to be able to access you electrs from outside of your LAN

# https://www.raspberrypi.org/documentation/remote-access/web-server/nginx.md

echo ""
echo "***"
echo "Please type the domain/dynamicDNS you want to use for Electrs and press [ENTER]"
read YOUR_DOMAIN

echo ""
echo "***"
echo "Please type an email that will be used to register the SSL certificate and press [ENTER]"
read YOUR_EMAIL

echo ""
echo "***"
echo "Please confirm that the port 80 is forwarded to the IP of the RaspiBlitz by pressing [ENTER]" 
read key

echo ""
echo "***"
echo "installing Nginx"
echo "***"
echo ""

sudo apt-get install -y nginx
sudo /etc/init.d/nginx start

echo "allow port 80 on ufw"
sudo ufw allow 80

# https://certbot.eff.org/lets-encrypt/debianother-nginx
echo ""
echo "***"
echo "Installing certbot"
echo "Will ask for an email address and a domain name - a dynamic DNS can be used"
echo "Use the default settings in the other options"
echo "***"
echo ""

#wget https://dl.eff.org/certbot-auto
#chmod +x certbot-auto
#sudo ./certbot-auto --nginx

sudo apt install -y certbot
# get SSL cert
sudo certbot certonly -a standalone -m $YOUR_EMAIL --agree-tos -d $YOUR_DOMAIN --pre-hook "service nginx stop" --post-hook "service nginx start"


# Your certificate and chain have been saved at:
# /etc/letsencrypt/live/$YOUR_DOMAIN/fullchain.pem
# Your key file has been saved at:
# /etc/letsencrypt/live/$YOUR_DOMAIN/privkey.pem

echo ""
echo "***"
echo "Setting up certbot-auto renewal service"
echo "***"
echo ""

echo "
[Unit]
Description=Certbot-auto renewal service

[Timer]
OnBootSec=20min
OnCalendar=*-*-* 4:00:00

[Install]
WantedBy=timers.target
" | sudo tee -a /etc/systemd/system/certbot.timer

echo "
[Unit]
Description=Certbot-auto renewal service
After=bitcoind.service

[Service]
WorkingDirectory=/home/admin/
ExecStart=sudo certbot renew --pre-hook \"service nginx stop\" --post-hook \"service nginx start\"

User=admin
Group=admin
Type=simple
KillMode=process
TimeoutSec=60
Restart=always
RestartSec=60
" | sudo tee -a /etc/systemd/system/certbot.service

sudo systemctl enable certbot.timer

echo "Setting up nginx.conf"
echo "***"
echo ""

isElectrs=$(sudo cat /etc/nginx/nginx.conf 2>/dev/null | grep -c 'upstream electrs')
if [ ${isElectrs} -gt 0 ]; then
        echo "electrs is already configured with Nginx. To edit manually run \`sudo nano /etc/nginx/nginx.conf\`"

elif [ ${isElectrs} -eq 0 ]; then

        isStream=$(sudo cat /etc/nginx/nginx.conf 2>/dev/null | grep -c 'stream {')
        if [ ${isStream} -eq 0 ]; then

        echo "
stream {
        upstream electrs {
                server 127.0.0.1:50001;
        }
        server {
                listen 50002;
                proxy_pass electrs;
                ssl_certificate /etc/letsencrypt/live/$YOUR_DOMAIN/fullchain.pem;
                ssl_certificate_key /etc/letsencrypt/live/$YOUR_DOMAIN/privkey.pem;
                ssl_session_cache shared:SSL-electrs:1m;
                ssl_session_timeout 4h;
                ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
                ssl_prefer_server_ciphers on;
        }
}" | sudo tee -a /etc/nginx/nginx.conf

        elif [ ${isStream} -eq 1 ]; then
                sudo truncate -s-2 /etc/nginx/nginx.conf
                echo "

        upstream electrs {
                server 127.0.0.1:50001;
        }
        server {
                listen 50002;
                proxy_pass electrs;
                ssl_certificate /etc/letsencrypt/live/$YOUR_DOMAIN/fullchain.pem;
                ssl_certificate_key /etc/letsencrypt/live/$YOUR_DOMAIN/privkey.pem;
                ssl_session_cache shared:SSL-electrs:1m;
                ssl_session_timeout 4h;
                ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
                ssl_prefer_server_ciphers on;
        }
}" | sudo tee -a /etc/nginx/nginx.conf

        elif [ ${isStream} -gt 1 ]; then

                echo " Too many \`stream\` commands in nginx.conf. Please edit manually: \`sudo nano /etc/nginx/nginx.conf\` and retry"
                exit 1
        fi
fi

echo "allow port 50002 on ufw"
sudo ufw allow 50002

sudo systemctl enable nginx
sudo systemctl restart nginx

echo ""
echo "To connect from outside of the local network make sure the port 50002 is forwarded on your router"
echo "Eclair mobile wallet: In the \`Network info\` set the \`Current Electrum server\` to \`$YOUR_DOMAIN:50002\`"
echo "Electrum wallet: start with the options \`electrum --oneserver --server $YOUR_DOMAIN:50002:s"
echo ""
