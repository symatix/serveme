#!/bin/bash
# run command as sudo
# sudo ./serveMe.sh [appName] [appPort] [username] [password] [serverIP] [gatewayIP] [dns] [appDomain]

# first to start setting up the environment
# we gonna install some stuff

clear
echo
echo
echo ".---------------------------------."
echo "|  .---------------------------.  |"
echo "|[]|                           |[]|"
echo "|  |                           |  |"
echo "|  |       server setup        |  |"
echo "|  |             &             |  |"
echo "|  |       first deploy        |  |"
echo "|  |                           |  |"
echo "|  |                           |  |"
echo "|  |           for lz ppl      |  |"
echo "|  |                 ...like me|  |"
echo "|  '---------------------------'  |"
echo "|      __________________ _____   |"
echo "|     |   ___            |     |  |"
echo "|     |  |   |           |     |  |"
echo "|     |  |   |           |     |  |"
echo "|     |  |   |           |     |  |"
echo "|     |  |___|           |     |  |"
echo "\_____|__________________|_____|__|"
sleep 2
echo
echo
echo "we gonna start now, so get some coffe and look away"
echo
sleep 2
echo "getting everything up to date"
sleep 1


# get everything up to date
apt-get update && apt-get upgrade --yes
apt-get install curl build-essential git nginx mongodb g++ npm nodejs-legacy glances --yes



clear
echo "setting up config files and environment"
sleep 2
echo "...by magic."


# add mongo to environment and create admins
echo 'MONGO_URL="mongodb://localhost:27017"' >> /etc/environment 


cat > addMongoUsers.js << EOF
use admin
db.createUser({user: "gazda",pwd: "gazdadb",roles: [{ role: "userAdminAnyDatabase", db: "admin" },{ role: "readWriteAnyDatabase", db: "admin" },{ role: "dbAdminAnyDatabase", db: "admin" },{ role: "clusterAdmin", db: "admin" }]})
use $1
db.createUser({ user: "$1",pwd: "$4",roles: [{ role: "readWrite", db: "$1" }]})
EOF
mongo < addMongoUsers.js
rm addMongoUsers.js
sed -i 's/#auth = true.*$/auth = tru/eg' /etc/mongodb.conf
# setting up service
cd /etc/systemd/system
cat > $1.service << EOF1
[Service]
ExecStart=/usr/bin/node /home/$3/croartia/bundle/main.js
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$1
User=$3
Group=$3
Environment=NODE_ENV=production
Environment=PORT=$2
Environment=HTTP_FORWARDED_COUNT=1
Environment=MONGO_URL=mongodb://$1:$4@localhost:27017/$1
Environment=ROOT_URL=http://$8

[Install]
WantedBy=multi-user.target
EOF1
# reload daemon to pick up new service file
systemctl daemon-reload

# setting up nginx server
cd /etc/nginx
cp nginx.conf nginx.conf.bkp
sed -i "/types_hash_max_size/a client_max_body_size 256m;" nginx.conf
cd /etc/nginx/sites-enabled
cat > $1 << EOF2
server {
    listen 80;
    server_name $8;
    location / {
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header Host \$http_host;
        proxy_pass http://127.0.0.1:$2;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF2
cp $1 /etc/nginx/sites-available/$1
rm default
rm /etc/nginx/sites-available/default
# restart service to pick up new config and routes
service nginx restart


echo
echo
echo "poof! done."
sleep 2
clear
echo "creating user and making him cosy inside the system"
sleep 1
echo "cosy like..."
sleep 1
echo "installing more apps and stuff..."
echo
echo


# now to take care of the user and it's environment
adduser --quiet --disabled-password --shell /bin/bash --home /home/$3 --gecos "User" $3
echo "$3:$4" | chpasswd
echo 'meteor ALL = (root) NOPASSWD: /bin/systemctl restart $1.service, /bin/systemctl start $1.service, /bin/systemctl stop $1.service, /bin/systemctl status $1.service' > /etc/sudoers.d/$1
# installing meteor
curl https://install.meteor.com | sh
# gonna run some stuff as meteor now
su $3 <<EOF
git clone https://github.com/creationix/nvm.git ~/.nvm
sed -i -e '1i [[ -s $HOME/.nvm/nvm.sh ]] && . $HOME/.nvm/nvm.sh' ~/.bashrc
source ~/.bashrc
nvm install 4.7.2 && nvm alias default 4.7.2
EOF
# need this globaly for meteor2node conversion
npm install -g demeteorizer

echo
echo
echo
echo
echo "boom!"
sleep 2
clear
echo "now gonna deploy the app"
sleep 2
echo "...pull the repo, make it a node and whatnot..."
sleep 3
echo
echo
echo



# running stuff as meteor again, this is the part where we deploy the app
# note to self: change the pull ending to option variable after croartia
su - $3 <<EOF
cd ~
mkdir $1
cd $1
mkdir source
cd source
git init
git pull https://github.com/symatix/cro
meteor npm install
meteor npm install babel-runtime
meteor npm install bcrypt
demeteorizer -o ~/$1
cd ~/$1/bundle/programs/server
npm install
npm install babel-runtime
npm install bcrypt
EOF


echo
echo
echo "app deployed"
echo
echo "setting up network interface to static ip and starting the app..."
sleep 3
echo



#ok, now everything is done, lets's set up the network adapter
cd /etc/network
cp interfaces interfaces.bkp
sed -i 's/dhcp.*$/static/g' interfaces
cat > networkAdapter << EOF3
address $5
netmask 255.255.255.0
gateway $6
dns-nameserver $7
EOF3
cat networkAdapter >> interfaces
rm networkAdapter
ifdown -a
ifup -a


#if everything went better than expected
systemctl start $1.service
systemctl enable $1.service

cd ~
cat > $1_specs.txt << EOF1
Specification - $1

[sysUser]
u: $3
p: $4

[mongoDB]
LAN: localhost:27017
location: /var/lib/mongodb

global admin
u: gazda
p: gazdadb

app admin
u: $1
p: $4

[app]
name: $1
LAN: http://$5
WAN: http://$8
port: 80
nodePort: $2
location: /home/$3/$1
EOF1

clear
echo 
echo
echo "            ^^                   @@@@@@@@@    $1 is now live@"
echo "       ^^       ^^            @@@@@@@@@@@@@@@    http://$5 LAN"
echo "                            @@@@@@@@@@@@@@@@@@     http://$8 WAN"
echo "  DONE! coffe time!        @@@@@@@@@@@@@@@@@@@@   ^^"
echo " ~~~~ ~~ ~~~~~ ~~~~~~~~ ~~ &&&&&&&&&&&&&&&&&&&& ~~~~~~~ ~~~~~~~~~~~ ~~~"
echo " ~         ~~   ~  ~       ~~~~~~~~~~~~~~~~~~~~ ~       ~~     ~~ ~"
echo "   ~      ~~      ~~ ~~ ~~  ~~~~~~~~~~~~~ ~~~~  ~     ~~~    ~ ~~~  ~ ~~"
echo "   ~  ~~     ~         ~      ~~~~~~  ~~ ~~~       ~~ ~ ~~  ~~ ~"
echo " ~  ~       ~ ~      ~           ~~ ~~~~~~  ~      ~~  ~             ~~"
echo "       ~             ~        ~      ~      ~~   ~             ~ "
echo
echo
echo
sleep 5
echo "by the way, there is $1_specs.txt"
sleep 2
echo
cat $1_specs.txt
echo
echo
echo "bye"
