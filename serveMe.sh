#!/bin/bash
# run command as sudo
# sudo ./serveMe.sh [appName] [appPort] [username] [password] [serverIP] [networkIP] [gatewayIP] [dns]

# first to start setting up the environment
# we gonna install some stuff


echo ".---------------------------------."
echo "|  .---------------------------.  |"
echo "|[]|                           |[]|"
echo "|  |                           |  |"
echo "|  |       automatic           |  |"
echo "|  |            deploy         |  |"
echo "|  |                system     |  |"
echo "|  |                           |  |"
echo "|  |        for lazy ppl       |  |"
echo "|  |                           |  |"
echo "|  |                           |  |"
echo "|  '---------------------------'  |"
echo "|      __________________ _____   |"
echo "|     |   ___            |     |  |"
echo "|     |  |   |           |     |  |"
echo "|     |  |   |           |     |  |"
echo "|     |  |   |           |     |  |"
echo "|     |  |___|           |     |  |"
echo "\_____|__________________|_____|__|"


echo "updating apt-get"

apt-get update && apt-get upgrade --yes
echo
echo "getting installations from repository"
echo
echo
apt-get install curl build-essential git nginx mongodb g++ npm nodejs-legacy glances


# add mongo to environment
echo "adding mongo url to environment"
echo 'MONGO_URL="mongodb://localhost:27017"' >> /etc/environment 


# setting up service
echo
echo "creating system service for the app"
cd /etc/systemd/system
cat > $1.service << EOF1
[Service]
ExecStart=/usr/bin/node /home/meteor/croartia/bundle/main.js
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$1
User=meteor
Group=meteor
Environment=NODE_ENV=production
Environment=PORT=$2
Environment=HTTP_FORWARDED_COUNT=1
Environment=MONGO_URL=mongodb://localhost:27017/$1
Environment=ROOT_URL=http://www.$1.com

[Install]
WantedBy=multi-user.target
EOF1

systemctl daemon-reload
echo "service created"


# setting up nginx server
echo "setting up nginx and writing routing files"
echo
cd /etc/nginx
cp nginx.conf nginx.conf.bkp
sed "/types_hash_max_size/a client_max_body_size 256m;" nginx.conf
echo "256m session per client allowed"
cd /etc/nginx/sites-enabled
cat > $1 << EOF2
server {
    listen 80;
    server_name www.$1.hr;
    location / {
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Host $http_host;
        proxy_pass http://127.0.0.1:$2;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF2
cp $1 /etc/nginx/sites-available/$1
echo "routing files created : restarting nginx"
service nginx restart


# now to take care of the user and it's environment
echo "adding $3 user"
adduser --quiet --disabled-password --shell /bin/bash --home /home/$3 --gecos "User" $3
# set password
echo "$3:$4" | chpasswd
echo 'meteor ALL = (root) NOPASSWD: /sbin/start $1, /sbin/stop $1, /sbin/restart $1' > /etc/sudoers.d/$1

echo "seting up environment for $3 user and deploying $1"
su $3 <<EOF
git clone https://github.com/creationix/nvm.git ~/.nvm
sed -i -e '1i [[ -s $HOME/.nvm/nvm.sh ]] && . $HOME/.nvm/nvm.sh' ~/.bashrc
source ~/.bashrc
nvm install 4.7.2 && nvm alias default 4.7.2
curl https://install.meteor.com | sh
sed -i -e '1i PATH="$PATH:/home/meteor/.meteor"' ~/.bashrc
source ~/.bashrc
npm install -g demeteorizer
git pull https://github.com/symatix/deployme
chmod +x ./deployMe.sh
./deployMe.sh $1
EOF

#ok, now everything is done, lets's set up the network adapter
cd /etc/network
ifconfig down
cp interfaces interfaces.bkp

sed -i '/inet dhcp/c\inet static' interfaces
echo 'address $5' >> interfaces
echo 'netmask 255.255.255.0' >> interfaces
echo 'network $6' >> interfaces
echo 'gateway $7' >> interfaces
echo 'dns-nameserver $8' >> interfaces
ifconfig up

#if everything went better than expected
systemctl start $1.service
systemctl enable $1.service

echo
echo
echo
echo
echo "that's it, to access your application on your LAN, go to http://$5"