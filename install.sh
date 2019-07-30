#!/bin/bash

# PATH TO YOUR HOSTS FILE
ETC_HOSTS=/etc/hosts

# DEFAULT IP FOR HOSTNAME
IP="127.0.0.1"

# Hostname to add/remove.
HOSTNAME=$1

domain="$(cut -d'.' -f1 <<<"$1")";

function installNginx() {
  sudo apt update
  sudo apt -y install nginx
  sudo ufw allow 'Nginx Full'
}

function confConfig() {
  sudo systemctl start nginx
  sudo systemctl enable nginx
  sudo mkdir -p /var/www/html/$1
  sudo chown -R $USER:$USER /var/www/html/
  sudo chmod -R 755 /var/www/html/
  uri='$uri';
  sudo tee /etc/nginx/sites-available/$1 <<EOF
  server {
    listen 80;
    listen [::]:80;
    root /var/www/html/$1;

    index index.php index.html index.htm index.nginx-debian.html;
    server_name $1 www.$1;
    location / {
      try_files $uri ${uri}/ =404;
    }
    location ~ \.php$ {
      include snippets/fastcgi-php.conf;
      fastcgi_pass unix:/run/php/php7.2-fpm.sock;
    }
  }
EOF
  sudo ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/
  # sudo unlink /etc/nginx/sites-enabled/default
  sudo systemctl restart nginx
  sudo systemctl reload nginx
}

function installmySQL() {
  MYSQL_ROOT_PASSWORD=root
  WP_DB_PASSWORD=root
  WP_DB_USERNAME="root"
  echo "mysql-server-5.7 mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
  echo "mysql-server-5.7 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
  sudo apt install -y mysql-server
  echo -e "MySql is installed for root user with password : $MYSQL_ROOT_PASSWORD"
  mySQLConfig $1
}

function mySQLConfig() {
  sudo mysql -u root -proot <<EOF
    CREATE DATABASE ${domain}_db;
    GRANT ALL ON ${domain}_db.* TO 'root'@'localhost';
    FLUSH PRIVILEGES;
    exit;
EOF
}

function installPHP() {
  sudo apt install -y php-fpm
  sudo apt install -y php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip php-mysql
  sudo systemctl restart php7.2-fpm
}

function installWordPress() {
  cd /tmp
  curl -LO https://wordpress.org/latest.tar.gz
  tar xzvf latest.tar.gz
  cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
}

function configWordpress() {
  sudo cp -a /tmp/wordpress/. /var/www/html/$1
  sudo chown -R www-data:www-data /var/www/html/$1
  road=$pwd
  cd /var/www/html/$1
  sudo sed -i s/database_name_here/${domain}_db/ wp-config.php
  sudo sed -i s/username_here/root/ wp-config.php
  sudo sed -i s/password_here/root/ wp-config.php
  SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
  STRING='put your unique phrase here'
  printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s wp-config.php
  cd $road
}

function removehost() {
  if [ -n "$(grep $HOSTNAME /etc/hosts)" ]; then
    echo "$HOSTNAME Found in your $ETC_HOSTS, Removing now..."
    sudo sed -i".bak" "/$HOSTNAME/d" $ETC_HOSTS
  else
    echo "$HOSTNAME was not found in your $ETC_HOSTS"
  fi
}

function addhost() {
  HOSTNAME=$1
  HOSTS_LINE="$IP\t$HOSTNAME"
  if [ -n "$(grep $HOSTNAME /etc/hosts)" ]; then
    echo "$HOSTNAME already exists : $(grep $HOSTNAME $ETC_HOSTS)"
  else
    echo "Adding $HOSTNAME to your $ETC_HOSTS"
    sudo -- sh -c -e "echo '$HOSTS_LINE' >> /etc/hosts"

    if [ -n "$(grep $HOSTNAME /etc/hosts)" ]; then
      echo "$HOSTNAME was added succesfully \n $(grep $HOSTNAME /etc/hosts)"
    else
      echo "Failed to Add $HOSTNAME, Try again!"
    fi
  fi
}

dpkg -l | grep 'nginx'
if [ $? == 0 ]; then
  echo "Nginx is installed !!!"
  # nginxConifg $1
else
  installNginx $1
fi

dpkg -l | grep 'mysql'
if [ $? == 0 ]; then
  echo "MySQL is installed !!!"
  mySQLConfig $1 $domain
else
  installmySQL
fi

dpkg -l | grep 'php'
if [ $? == 0 ]; then
  echo "PHP is installed !!!"
else
  installPHP
fi
installWordPress $1
confConfig $1
configWordpress $1 $domain
addhost $1

sudo systemctl restart nginx
sudo systemctl reload nginx
