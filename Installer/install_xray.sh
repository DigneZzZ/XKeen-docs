#!/bin/sh

# Определите архитектуру процессора
ARCH=$(uname -m)

# Проверка аргумента командной строки
ACTION=$1
if [ "$ACTION" != "install" ] && [ "$ACTION" != "recover" ]; then
  echo "Usage: $0 {install|recover}"
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
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Действие в зависимости от параметра
if [ "$ACTION" = "install" ]; then
  # Остановите xkeen
  echo "Stopping xkeen..."
  xkeen -stop

  # Убедитесь, что /opt/sbin существует
  mkdir -p /opt/sbin

  # Проверьте, существует ли уже файл xray и архивируйте его
  if [ -f /opt/sbin/xray ]; then
    echo "Archiving existing xray file..."
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    # Сохраните права доступа
    STAT=$(stat -c "%a %U %G" /opt/sbin/xray)
    echo "$STAT" > /opt/sbin/xray_permissions
    mv /opt/sbin/xray /opt/sbin/xray_backup_$TIMESTAMP
  fi

  # Скачайте архив
  echo "Downloading $ARCHIVE..."
  curl -L -o /tmp/$ARCHIVE $URL

  # Распакуйте архив в /opt/sbin
  echo "Extracting $ARCHIVE..."
  unzip /tmp/$ARCHIVE -d /opt/sbin

  # Установите права на исполняемый файл
  echo "Setting permissions..."
  chmod 755 /opt/sbin/xray

  # Удалите архив
  echo "Cleaning up..."
  rm /tmp/$ARCHIVE

  # Запустите xkeen
  echo "Starting xkeen..."
  xkeen -start

  echo "Installation complete."

elif [ "$ACTION" = "recover" ]; then
  # Остановите xkeen
  echo "Stopping xkeen..."
  xkeen -stop

  # Проверьте, есть ли резервные копии
  BACKUP_FILE=$(ls -t /opt/sbin/xray_backup_* 2>/dev/null | head -1)
  if [ -f "$BACKUP_FILE" ]; then
    echo "Restoring original xray file..."
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
    echo "No backup file found. Cannot recover."
    exit 1
  fi

  # Запустите xkeen
  echo "Starting xkeen..."
  xkeen -start

  echo "Recovery complete."

fi
