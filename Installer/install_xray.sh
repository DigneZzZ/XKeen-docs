#!/bin/sh

# Цвета для вывода сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Определите архитектуру процессора
ARCH=$(uname -m)
printf "${GREEN}Определенная архитектура: $ARCH${NC}\n"

# Дополнительная информация о процессоре для проверки
lscpu | grep -E 'Architecture|Model name|CPU(s)'

# Проверка аргумента командной строки
ACTION=$1
if [ "$ACTION" != "install" ] && [ "$ACTION" != "recover" ]; then
  printf "${RED}Использование: $0 {install|recover}${NC}\n"
  exit 1
fi

# Установите переменные для URL и имени архива в зависимости от архитектуры
case $ARCH in
  "aarch64")
    URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip"
    ARCHIVE="Xray-linux-arm64-v8a.zip"
    ;;
  "mips"|"mipsle")
    URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-mips32le.zip"
    ARCHIVE="Xray-linux-mips32le.zip"
    ;;
  "mips64")
    URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-mips64.zip"
    ARCHIVE="Xray-linux-mips64.zip"
    ;;
  "mips64le")
    URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-mips64le.zip"
    ARCHIVE="Xray-linux-mips64le.zip"
    ;;
  *)
    printf "${RED}Неизвестная архитектура: $ARCH${NC}\n"
    exit 1
    ;;
esac

# Действие в зависимости от параметра
if [ "$ACTION" = "install" ]; then
  # Остановите xkeen
  printf "${GREEN}Остановка xkeen...${NC}\n"
  xkeen -stop

  # Убедитесь, что /opt/sbin существует
  mkdir -p /opt/sbin

  # Проверьте, существует ли уже файл xray и архивируйте его
  if [ -f /opt/sbin/xray ]; then
    printf "${GREEN}Архивация существующего файла xray...${NC}\n"
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    STAT=$(stat -c "%a %U %G" /opt/sbin/xray)
    echo "$STAT" > /opt/sbin/xray_permissions
    mv /opt/sbin/xray /opt/sbin/xray_backup_$TIMESTAMP
  fi

  # Скачайте архив
  printf "${GREEN}Скачивание $ARCHIVE...${NC}\n"
  curl -L -o /tmp/$ARCHIVE $URL

  # Извлеките только нужный файл из архива
  printf "${GREEN}Извлечение xray из $ARCHIVE...${NC}\n"
  TEMP_DIR=$(mktemp -d)
  unzip -j /tmp/$ARCHIVE xray -d $TEMP_DIR

  # Переместите только нужный файл в /opt/sbin
  printf "${GREEN}Перемещение xray в /opt/sbin...${NC}\n"
  mv $TEMP_DIR/xray /opt/sbin/xray

  # Установите права на исполняемый файл
  printf "${GREEN}Установка прав доступа...${NC}\n"
  chmod 755 /opt/sbin/xray

  # Удалите временную директорию и архив
  printf "${GREEN}Очистка...${NC}\n"
  rm -rf $TEMP_DIR
  rm /tmp/$ARCHIVE

  # Запустите xkeen
  printf "${GREEN}Запуск xkeen...${NC}\n"
  xkeen -start

  printf "${GREEN}Установка завершена.${NC}\n"

elif [ "$ACTION" = "recover" ]; then
  # Остановите xkeen
  printf "${GREEN}Остановка xkeen...${NC}\n"
  xkeen -stop

  # Проверьте, есть ли резервные копии
  BACKUP_FILE=$(ls -t /opt/sbin/xray_backup_* 2>/dev/null | head -1)
  if [ -f "$BACKUP_FILE" ]; then
    printf "${GREEN}Восстановление оригинального файла xray...${NC}\n"
    mv "$BACKUP_FILE" /opt/sbin/xray

    # Восстановите права доступа
    if [ -f /opt/sbin/xray_permissions ]; then
      PERMS=$(cat /opt/sbin/xray_permissions)
      chmod $PERMS /opt/sbin/xray
      rm /opt/sbin/xray_permissions
    else
      chmod 755 /opt/sbin/xray
    fi
  else
    printf "${RED}Резервная копия не найдена. Восстановление невозможно.${NC}\n"
    exit 1
  fi

  # Запустите xkeen
  printf "${GREEN}Запуск xkeen...${NC}\n"
  xkeen -start

  printf "${GREEN}Восстановление завершено.${NC}\n"
fi
