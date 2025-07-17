#!/bin/bash
# Конфиг по большей части сгенерирован нейронкой

# Установка зависимостей
install_dependencies() {
    echo "Установка зависимостей..."
    sudo apt update
    sudo apt install -y docker.io docker-compose nginx apache2-utils ufw
    sudo systemctl enable --now docker
}

# Настройка UFW
configure_ufw() {
    echo "Настройка фаервола..."
    #для http nginx, который будет слать в owntracker?
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    #для ssh
    sudo ufw allow 22/tcp
    sudo ufw allow 1883/tcp
    sudo ufw allow 1883
    sudo ufw enable
}

# Запуск OwnTracks через Docker
setup_containers() {
    echo "Запуск OwnTracks..."
    docker kill $(docker ps -q)
    docker compose up -d


    container_name=$(docker compose -p owntrack ps -a --format "{{.Names}}" | grep mosquitto)
    # плохо, так как пароль будет виден в истории комманд
    docker exec -it "$container_name" mosquitto_passwd -b /mosquitto/config/passwd "${OWNTRACKRECORDER_USER}" "${OWNTRACKRECORDER_PASSWORD}"
    docker kill $(docker ps -q)
    docker compose up -d
}

# Настройка Nginx
configure_nginx() {
    echo "Настройка Nginx..."

    sudo htpasswd -b -c /etc/nginx/.htpasswd "${AUTH_USER}" "${AUTH_PASS}"

    container_ip_recorder=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(sudo docker compose -p owntrack ps -a --format "{{.Names}}" | grep recorder))
    container_ip_frontend=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(sudo docker compose -p owntrack ps -a --format "{{.Names}}" | grep frontend))
    
    # Создаём конфиг Nginx
    cat <<EOF | sudo tee /etc/nginx/sites-available/owntracks > /dev/null
server {
    listen 80 default_server;
    server_name _;
    
    location /owntrack/ws/  {
        proxy_pass http://$container_ip_recorder:8083/ws/;
	proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Дополнительные заголовки
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /owntrack/  {
        auth_basic "Restricted Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://$container_ip_recorder:8083/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /frontend/ {
        auth_basic "Restricted Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://$container_ip_frontend:8081/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    sudo ln -fs /etc/nginx/sites-available/owntracks /etc/nginx/sites-enabled/
    sudo rm /etc/nginx/sites-enabled/default
    sudo nginx -t && sudo systemctl restart nginx
}

# Главная функция
main() {
    install_dependencies
    configure_ufw
    setup_containers
    configure_nginx

}

# переменные среды
set -a && source .env && set +a
# запуск
main