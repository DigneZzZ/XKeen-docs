#!/bin/sh

# Цвета для вывода сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Определите архитектуру процессора
ARCH=$(uname -m)

# Проверка аргумента командной строки
ACTION=$1
if [ "$ACTION" != "install" ] && [ "$ACTION" != "recover" ]; then
  echo -e "${RED}Использование: $0 {install|recover}${NC}"
  exit 1
fi

# Установите переменные для URL и имени архива в зависимости от архитектуры
case $ARCH in
  "aarch64")
    URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip"
    ARCHIVE="Xray-linux-arm64-v8a.zip"
    ;;
  "mips32")
    URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-mips32.zip"
    ARCHIVE="Xray-linux-mips32.zip"
    ;;
  "mipsle")
    URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-mips32le.zip"
    ARCHIVE="Xray-linux-mips32le.zip"
    ;;
  *)
    echo -e "${RED}Неизвестная архитектура: $ARCH${NC}"
    exit 1
    ;;
esac

# Действие в зависимости от параметра
if [ "$ACTION" = "install" ]; then
  # Остановите xkeen
  echo -e "${GREEN}Остановка xkeen...${NC}"
  xkeen -stop

  # Убедитесь, что /opt/sbin существует
  mkdir -p /opt/sbin

  # Проверьте, существует ли уже файл xray и архивируйте его
  if [ -f /opt/sbin/xray ]; then
    echo -e "${GREEN}Архивация существующего файла xray...${NC}"
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    STAT=$(stat -c "%a %U %G" /opt/sbin/xray)
    echo "$STAT" > /opt/sbin/xray_permissions
    mv /opt/sbin/xray /opt/sbin/xray_backup_$TIMESTAMP
  fi

  # Скачайте архив
  echo -e "${GREEN}Скачивание $ARCHIVE...${NC}"
  curl -L -o /tmp/$ARCHIVE $URL

  # Извлеките только нужный файл из архива
  echo -e "${GREEN}Извлечение xray из $ARCHIVE...${NC}"
  TEMP_DIR=$(mktemp -d)
  unzip -j /tmp/$ARCHIVE xray -d $TEMP_DIR

  # Переместите только нужный файл в /opt/sbin
  echo -e "${GREEN}Перемещение xray в /opt/sbin...${NC}"
  mv $TEMP_DIR/xray /opt/sbin/xray

  # Установите права на исполняемый файл
  echo -e "${GREEN}Установка прав доступа...${NC}"
  chmod 755 /opt/sbin/xray

  # Удалите временную директорию и архив
  echo -e "${GREEN}Очистка...${NC}"
  rm -rf $TEMP_DIR
  rm /tmp/$ARCHIVE

  # Запустите xkeen
  echo -e "${GREEN}Запуск xkeen...${NC}"
  xkeen -start

  echo -e "${GREEN}Установка завершена.${NC}"

elif [ "$ACTION" = "recover" ]; then
  # Остановите xkeen
  echo -e "${GREEN}Остановка xkeen...${NC}"
  xkeen -stop

  # Проверьте, есть ли резервные копии
  BACKUP_FILE=$(ls -t /opt/sbin/xray_backup_* 2>/dev/null | head -1)
  if [ -f "$BACKUP_FILE" ]; then
    echo -e "${GREEN}Восстановление оригинального файла xray...${NC}"
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
    echo -e "${RED}Резервная копия не найдена. Восстановление невозможно.${NC}"
    exit 1
  fi

  # Запустите xkeen
  echo -e "${GREEN}Запуск xkeen...${NC}"
  xkeen -start

  echo -e "${GREEN}Восстановление завершено.${NC}"
fi
