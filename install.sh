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
    confConfig
  fi
}

confConfig() {
  sudo rm -rf /etc/nginx/sites-available/$1
  sudo tee /etc/nginx/sites-available/$1 <<EOF
server {
    listen 80;
    listen [::]:80;
    root /var/www/html/$1;
    
    index index.php index.html index.htm index.nginx-debian.html;
    server_name $1 www.$1;
    location / {
        try_files $uri ${uri}/ =404;
        try_files $uri $uri/ /index.php$is_args$args;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.2-fpm.sock;
    }
  }
EOF
  sudo ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/
  sudo systemctl restart nginx
  sudo nginx -t
  if [ $? == 0 ]; then
    sudo systemctl reload nginx
  fi
}

installmySQL() {
  MYSQL_ROOT_PASSWORD=root
  WP_DB_PASSWORD=root
  WP_DB_USERNAME="root"
  echo "mysql-server-5.7 mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
  echo "mysql-server-5.7 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
  sudo apt install -y mysql-server
  echo -e "MySql is installed for root user with password : $MYSQL_ROOT_PASSWORD"
}

mySQLConfig() {
  mysql -u root -proot <<EOF
    CREATE DATABASE $1 DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
    GRANT ALL ON $1.* TO 'root'@'localhost' IDENTIFIED BY 'root';
    FLUSH PRIVILEGES;
    EXIT;
EOF
}

installPHP() {
  sudo apt install -y php-fpm
  sudo apt install -y php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip
  sudo systemctl restart php7.2-fpm
}

dpkg -l | grep 'nginx'
if [ $? == 0 ]; then
  echo "Nginx is installed !!!"
else
  installNginx $1
fi

dpkg -l | grep 'mysql'
if [ $? == 0 ]; then
  echo "MySQL is installed !!!"
  mySQLConfig $1
else
  installmySQL
fi

dpkg -l | grep 'php'
if [ $? == 0 ]; then
  echo "PHP is installed !!!"
else
  installPHP
  confConfig $1
fi

