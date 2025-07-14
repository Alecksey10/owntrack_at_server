# owntrack_at_server

## О чём

Попытка частично автоматизировать процесс разворачивания owntracker

## Запуск. Installation

1) получаем репозиторий
2) переходим в директорию src
3) заполняем .env под себя
   1) брокер mosquitto (OWNTRACKRECORDER_USER упрощённо - то, к чему с телефона подключаться будем)
   2) AUTH_USER - для доступа к recorder
4) запускам main.sh

### Содержимое

* mosquitto container
* owntracker-recorder container
* nginx

#### Зачем nginx

не курил мануалы, не знаю, поддерживает ли owntracker-recorder систему пользователей, поэтому nginx будет выступать в роли reverse proxy для owntracker-recorder для хоть какой-либо базовой защиты

## checklist (ДОДЕЛАТЬ)

* mosquitto container
  * задать пользователя A
* owntracker-recorder container
  * развернуть
  * задать пользователя для авторизации в mosquitto (пользователь A)
* nginx
  * задать пользователя для авторизации B
* Прочее
  * Безопасность сервера
    * [ ] настройка firewall (опционально)
    * [ ] отключение доступа не по ssh

### Итого, порядок действий (ДОДЕЛАТЬ)

:white_square_button: - опционально

1) Настройка окружения
   1) установка зависимостей
      1) docker
      2) nginx
      3) :white_square_button: ufw
   2) .
2) настройка owntracker
   1) запуск docker-compose
   2) регистрация пользователя
   3) sudo docker exec -it <имя-запущенного-контейнера-mosquitto> mosquitto_passwd -c /mosquitto/config/passwd <никнейм>
далее вводим пароль
   4) настройка nginx
      1) sudo apt install nginx apache2-utils
      2) sudo htpasswd -c /etc/nginx/.htpasswd owntracksuser
        узнаём ip контейнера
        docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <имя-owntrack-контейнера>
      3) создаём конфигурационный файл nginx для нашего ресурса
    sudo nano /etc/nginx/sites-available/owntracks
    server {
        listen 80;
        server_name *;

        location / {
            auth_basic "Restricted Area";
            auth_basic_user_file /etc/nginx/.htpasswd;

            proxy_pass http://ip-контейнера:8083;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }

## Что доделать

* [ ] read me file
* [ ] проверить безопасность
* [ ] переделать bash файл установки, так как он нестабилен
