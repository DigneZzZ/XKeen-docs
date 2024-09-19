#!/bin/sh

# Цвета для вывода сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m' # Желтый цвет
NC='\033[0m' # Без цвета

# Версия скрипта
VERSION="1.5.0"

# Вывод версии скрипта
printf "${GREEN}Версия скрипта: $VERSION${NC}\n"

# Функция для вывода справки
show_help() {
    printf "${GREEN}Использование: ${GREEN}./install_xray.sh ${YELLOW}{command}${NC}\n\n"
    printf "${GREEN}Команды:${NC}\n"
    printf "  ${YELLOW}update|-u [version]${NC} - Обновить Xray. Если версия не указана, будет выполнено обновление до последней доступной версии.\n"
    printf "  ${YELLOW}recover|-r${NC}          - Восстановить Xray из резервной копии.\n"
    printf "  ${YELLOW}help|-h${NC}             - Показать это сообщение.\n"
}

# Функция для отключения обновлений Xkeen
disable_xkeen_update() {
    printf "${YELLOW}Отключение автоматических обновлений Xkeen...${NC}\n"
    
    # Отключение обновлений Xkeen с помощью команды xkeen -dxc без вывода сообщений
    xkeen -dxc > /dev/null 2>&1
    
    printf "${GREEN}Автоматическое обновление Xray через Xkeen отключено.${NC}\n"
}

# Определите архитектуру процессора
ARCH=$(uname -m)
printf "${GREEN}Определенная архитектура: $ARCH${NC}\n"

# Дополнительная информация о процессоре для проверки
lscpu | grep -E 'Architecture|Model name|CPU(s)'

# Проверка аргумента командной строки
ACTION=$1
VERSION_ARG=$2

case $ACTION in
    "update"|-u)
        ACTION="update"
        ;;
    "recover"|-r)
        ACTION="recover"
        ;;
    "help"|-h)
        ACTION="help"
        ;;
    *)
        if [ "$ACTION" != "install" ] && [ "$ACTION" != "update" ] && [ "$ACTION" != "recover" ] && [ "$ACTION" != "help" ]; then
            printf "${RED}Использование: ${GREEN}./install_xray.sh ${YELLOW}{update|-u [version] | recover|-r | help|-h}${NC}\n"
            exit 1
        fi
        ;;
esac

if [ "$ACTION" = "help" ]; then
    show_help
    exit 0
fi

if [ "$ACTION" = "update" ]; then
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

    # Остановка xkeen
    printf "${GREEN}Остановка xkeen...${NC}\n"
    xkeen -stop

    # Убедитесь, что /opt/sbin существует
    mkdir -p /opt/sbin

    # Создайте директорию для резервных копий, если она не существует
    BACKUP_DIR="/opt/backups"
    mkdir -p $BACKUP_DIR

    # Проверка наличия резервной копии в /opt/backups
    BACKUP_FILE="$BACKUP_DIR/xray_backup_v1.8.4"
    
    if [ -f /opt/sbin/xray ]; then
        if [ ! -f "$BACKUP_FILE" ]; then
            printf "${GREEN}Архивация существующего файла xray...${NC}\n"
            # Сохраните права доступа текущего файла xray
            ls -l /opt/sbin/xray | awk '{print $1}' > $BACKUP_DIR/xray_permissions
            mv /opt/sbin/xray "$BACKUP_FILE"
        else
            printf "${YELLOW}Резервная копия с именем xray_backup_v1.8.4 уже существует.${NC}\n"
        fi
    fi

    # Скачайте архив
    printf "${GREEN}Скачивание $ARCHIVE...${NC}\n"
    curl -L -o /tmp/$ARCHIVE $URL

    # Извлечение только нужного файла из архива
    printf "${GREEN}Извлечение xray из $ARCHIVE...${NC}\n"
    TEMP_DIR=$(mktemp -d)
    unzip -j /tmp/$ARCHIVE xray -d $TEMP_DIR

    # Перемещение только нужного файла в /opt/sbin
    printf "${GREEN}Перемещение xray в /opt/sbin...${NC}\n"
    mv $TEMP_DIR/xray /opt/sbin/xray

    # Установка прав на исполняемый файл
    printf "${GREEN}Установка прав доступа...${NC}\n"
    chmod 755 /opt/sbin/xray

    # Удаление временной директории и архива
    printf "${GREEN}Очистка...${NC}\n"
    rm -rf $TEMP_DIR
    rm /tmp/$ARCHIVE

    # Запуск xkeen
    printf "${GREEN}Запуск xkeen...${NC}\n"
    xkeen -start

    # Вызов функции для отключения обновлений только после успешного завершения установки/обновления
    disable_xkeen_update

    printf "${GREEN}Обновление завершено.${NC}\n"

elif [ "$ACTION" = "recover" ]; then
    # Остановка xkeen
    printf "${GREEN}Остановка xkeen...${NC}\n"
    xkeen -stop

    # Проверка наличия резервной копии
    BACKUP_FILE="/opt/backups/xray_backup_v1.8.4"

    if [ -f "$BACKUP_FILE" ]; then
        printf "${GREEN}Восстановление оригинального файла xray...${NC}\n"
        mv "$BACKUP_FILE" /opt/sbin/xray

        # Восстановите права доступа
        if [ -f /opt/backups/xray_permissions ]; then
            PERMS=$(cat /opt/backups/xray_permissions)
            chmod $PERMS /opt/sbin/xray
            rm /opt/backups/xray_permissions
        else
            chmod 755 /opt/sbin/xray
        fi
    else
        printf "${RED}Резервная копия не найдена. Восстановление невозможно.${NC}\n"
        exit 1
    fi

    # Запуск xkeen
    printf "${GREEN}Запуск xkeen...${NC}\n"
    xkeen -start

    printf "${GREEN}Восстановление завершено.${NC}\n"
fi
