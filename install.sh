#!/bin/bash

# PATH TO YOUR HOSTS FILE
ETC_HOSTS=/etc/hosts

# DEFAULT IP FOR HOSTNAME
IP="127.0.0.1"

# Hostname to add/remove.
HOSTNAME=$1

function installNginx() {
  sudo apt update
  sudo apt -y install nginx
  sudo ufw allow 'Nginx Full'
  # nginxConifg $1
}

function nginxConifg() {
  curl -4 localhost
  uri='$uri'
  if [ $? == 0 ]; then
    echo "Works"
    sudo systemctl start nginx
    sudo systemctl enable nginx
    sudo mkdir -p /var/www/html/$1
    sudo chown -R $USER:$USER /var/www/html
    sudo chmod -R 755 /var/www/html
    sudo tee /etc/nginx/sites-available/$1 <<EOF
    server {
      listen 80;
      listen [::]:80;
      root /var/www/html/$1;

      index index.php index.html index.htm index.nginx-debian.html;
      server_name $1 www.$1;
      location / {
        try_files $uri {$uri}/ =404;
      }
    }
EOF
    sudo ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/
    sudo systemctl restart nginx
  fi
}

function confConfig() {
  sudo systemctl start nginx
  sudo systemctl enable nginx
  sudo mkdir -p /var/www/html/$1
  sudo chown -R $USER:$USER /var/www/html
  sudo chmod -R 755 /var/www/html
  # sudo rm -rf /etc/nginx/sites-available/$1
  # sudo rm -rf /etc/nginx/sites-enabled/$1
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
  mySQLConfig
}

function mySQLConfig() {
  sudo mysql -u root -proot <<EOF
    CREATE DATABASE example;
    GRANT ALL ON wordpress.* TO 'root'@'localhost';
    FLUSH PRIVILEGES;
    EXIT;
EOF
}

function installPHP() {
  sudo apt install -y php-fpm
  sudo apt install -y php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip
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
  sudo sed -i s/database_name_here/wordpress/ wp-config.php
  sudo sed -i s/username_here/root/ wp-config.php
  sudo sed -i s/password_here/root/ wp-config.php
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
  mySQLConfig
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
configWordpress $1
addhost $1

sudo systemctl restart nginx
