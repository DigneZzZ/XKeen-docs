#!/bin/sh

# Цвета для вывода сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Версия скрипта
VERSION="1.3.0"

# Вывод версии скрипта
printf "${GREEN}Версия скрипта: $VERSION${NC}\n"

# Функция для вывода справки
show_help() {
    printf "${GREEN}Использование: $0 {install|recover|help} [version]${NC}\n"
    printf "${GREEN}  install [version] - Установить Xray.${NC}\n"
    printf "${GREEN}    [version] - Опциональный параметр. Номер версии Xray для установки (например, 1.8.4).${NC}\n"
    printf "${GREEN}    Если версия не указана, будет загружена последняя доступная версия.${NC}\n"
    printf "${GREEN}  recover - Восстановить Xray из резервной копии.${NC}\n"
    printf "${GREEN}  help - Показать это сообщение.${NC}\n"
}

# Определите архитектуру процессора
ARCH=$(uname -m)
printf "${GREEN}Определенная архитектура: $ARCH${NC}\n"

# Дополнительная информация о процессоре для проверки
lscpu | grep -E 'Architecture|Model name|CPU(s)'

# Проверка аргумента командной строки
ACTION=$1
VERSION_ARG=$2

if [ "$ACTION" != "install" ] && [ "$ACTION" != "recover" ] && [ "$ACTION" != "help" ]; then
  printf "${RED}Использование: $0 {install|recover|help} [version]${NC}\n"
  exit 1
fi

if [ "$ACTION" = "help" ]; then
    show_help
    exit 0
fi

# Установите переменные для URL и имени архива в зависимости от архитектуры и версии
if [ "$ACTION" = "install" ]; then
  if [ -n "$VERSION_ARG" ]; then
    VERSION_PATH="v$VERSION_ARG"
    URL_BASE="https://github.com/XTLS/Xray-core/releases/download/$VERSION_PATH"
  else
    VERSION_PATH="latest"
    URL_BASE="https://github.com/XTLS/Xray-core/releases/latest/download"
  fi

  case $ARCH in
    "aarch64")
      URL="$URL_BASE/Xray-linux-arm64-v8a.zip"
      ARCHIVE="Xray-linux-arm64-v8a.zip"
      ;;
    "mips"|"mipsle")
      URL="$URL_BASE/Xray-linux-mips32le.zip"
      ARCHIVE="Xray-linux-mips32le.zip"
      ;;
    "mips64")
      URL="$URL_BASE/Xray-linux-mips64.zip"
      ARCHIVE="Xray-linux-mips64.zip"
      ;;
    "mips64le")
      URL="$URL_BASE/Xray-linux-mips64le.zip"
      ARCHIVE="Xray-linux-mips64le.zip"
      ;;
    *)
      printf "${RED}Неизвестная архитектура: $ARCH${NC}\n"
      exit 1
      ;;
  esac

  # Действие в зависимости от параметра
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
    mv /opt/sbin/xray /opt/sbin/xray_backup_$VERSION-$TIMESTAMP
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
  BACKUP_FILE=$(ls -t /opt/sbin/xray_backup_v* 2>/dev/null | head -1)
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
