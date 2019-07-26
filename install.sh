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

installNginx $1