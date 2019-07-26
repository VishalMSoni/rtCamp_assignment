#!/bin/bash

installNginx() {
  sudo apt update
  sudo apt install nginx
  sudo ufw allow 'Nginx Full'
  curl -4 localhost
  if [ $? == 0 ]; then
    echo "Works"
    sudo systemctl start nginx
    sudo systemctl enable nginx
    sudo mkdir -p /var/www/$1/html
    sudo chown -R $USER:$USER /var/www/$1/html
    sudo chmod -R 755 /var/www/$1
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
  }
EOF
    sudo ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/
    sudo systemctl restart nginx
  fi
}

installmySQL() {
  MYSQL_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  WP_DB_PASSWORD=$MYSQL_ROOT_PASSWORD
  WP_DB_USERNAME="root"
  echo "mysql-server-5.7 mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
  echo "mysql-server-5.7 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
  sudo apt install -y mysql-server
  echo -e "MySql is installed for root user with password : \e[1m\e[32m$MYSQL_ROOT_PASSWORD"
}

dpkg -l | grep 'nginx'
if [ $? == 0 ]; then
  echo "Nginx is installed !!!"
else
  installNginx $1
fi

installmySQL

