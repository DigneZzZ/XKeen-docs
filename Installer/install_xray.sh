#!/bin/sh

# Определите архитектуру процессора
ARCH=$(uname -m)

# Проверка аргумента командной строки
ACTION=$1
if [ "$ACTION" != "install" ] && [ "$ACTION" != "recover" ]; then
  echo "Использование: $0 {install|recover}"
  exit 1
fi

# Установите переменные для URL и имени архива в зависимости от архитектуры
case $ARCH in
  "aarch64")
    URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip"
    ARCHIVE="Xray-linux-arm64-v8a.zip"
    ;;
  "mips"* )
    if [ "$ARCH" = "mips32" ]; then
      URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-mips32.zip"
      ARCHIVE="Xray-linux-mips32.zip"
    else
      URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-mips32le.zip"
      ARCHIVE="Xray-linux-mips32le.zip"
    fi
    ;;
  *)
    echo "Неизвестная архитектура: $ARCH"
    exit 1
    ;;
esac

# Действие в зависимости от параметра
if [ "$ACTION" = "install" ]; then
  # Остановите xkeen
  echo "Остановка xkeen..."
  xkeen -stop

  # Убедитесь, что /opt/sbin существует
  mkdir -p /opt/sbin

  # Проверьте, существует ли уже файл xray и архивируйте его
  if [ -f /opt/sbin/xray ]; then
    echo "Архивация существующего файла xray..."
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    STAT=$(stat -c "%a %U %G" /opt/sbin/xray)
    echo "$STAT" > /opt/sbin/xray_permissions
    mv /opt/sbin/xray /opt/sbin/xray_backup_$TIMESTAMP
  fi

  # Скачайте архив
  echo "Скачивание $ARCHIVE..."
  curl -L -o /tmp/$ARCHIVE $URL

  # Извлеките только нужный файл из архива
  echo "Извлечение xray из $ARCHIVE..."
  TEMP_DIR=$(mktemp -d)
  unzip -j /tmp/$ARCHIVE xray -d $TEMP_DIR

  # Переместите только нужный файл в /opt/sbin
  echo "Перемещение xray в /opt/sbin..."
  mv $TEMP_DIR/xray /opt/sbin/xray

  # Установите права на исполняемый файл
  echo "Установка прав доступа..."
  chmod 755 /opt/sbin/xray

  # Удалите временную директорию и архив
  echo "Очистка..."
  rm -rf $TEMP_DIR
  rm /tmp/$ARCHIVE

  # Запустите xkeen
  echo "Запуск xkeen..."
  xkeen -start

  echo "Установка завершена."

elif [ "$ACTION" = "recover" ]; then
  # Остановите xkeen
  echo "Остановка xkeen..."
  xkeen -stop

  # Проверьте, есть ли резервные копии
  BACKUP_FILE=$(ls -t /opt/sbin/xray_backup_* 2>/dev/null | head -1)
  if [ -f "$BACKUP_FILE" ]; then
    echo "Восстановление оригинального файла xray..."
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
    echo "Резервная копия не найдена. Восстановление невозможно."
    exit 1
  fi

  # Запустите xkeen
  echo "Запуск xkeen..."
  xkeen -start

  echo "Восстановление завершено."
fi
