#!/bin/bash

# Скрипт создания deb-пакета из собранных артефактов
# Создает минимальную структуру deb-пакета и упаковывает его

# Использование:
# ./package-deb.sh <режим> <staging-директория>
# где режим: release или debug

# Предполагается запуск внутри Docker контейнера

set -e  # Остановка при ошибке

# Подключаем утилиты
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Проверка аргументов
if [ $# -lt 2 ]; then
    log_error "Использование: $0 <режим> <staging-директория>"
    log_error "  режим: release или debug"
    log_error "  staging-директория: путь к директории с установленными файлами"
    exit 1
fi

BUILD_MODE="$1"
STAGING_DIR="$2"

# Проверка корректности режима
if [ "$BUILD_MODE" != "release" ] && [ "$BUILD_MODE" != "debug" ]; then
    log_error "Неверный режим: $BUILD_MODE (должен быть release или debug)"
    exit 1
fi

# Проверка существования staging-директории
if [ ! -d "$STAGING_DIR" ]; then
    log_error "Staging-директория не найдена: $STAGING_DIR"
    exit 1
fi

# Проверка наличия бинарника
JQ_BINARY="$STAGING_DIR/usr/local/bin/jq"
if [ ! -f "$JQ_BINARY" ]; then
    log_error "Бинарник jq не найден в $JQ_BINARY"
    exit 1
fi

log_info "Начало создания deb-пакета для режима $BUILD_MODE"

# Получаем ревизию
REVISION=$(get_revision)
log_info "Ревизия: $REVISION"

# Определяем версию jq из бинарника
JQ_VERSION=$("$JQ_BINARY" --version 2>/dev/null | head -1 | sed 's/jq-//' | sed 's/jq version //' | awk '{print $1}' || echo "1.0")
log_info "Версия jq: $JQ_VERSION"

# Создаем временную директорию для сборки пакета
PACKAGE_DIR="$STAGING_DIR/../deb-package"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Копируем содержимое staging-директории в пакетную директорию
log_info "Копирование файлов в пакетную директорию..."
cp -r "$STAGING_DIR"/* "$PACKAGE_DIR/"

# Создаем директорию DEBIAN для метаданных пакета
DEBIAN_DIR="$PACKAGE_DIR/DEBIAN"
mkdir -p "$DEBIAN_DIR"

# Определяем архитектуру
ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")

# Формируем имя пакета с ревизией
PACKAGE_NAME="jq-$BUILD_MODE"
PACKAGE_VERSION="${JQ_VERSION}-${REVISION}"

# Создаем файл control с минимальными метаданными
log_info "Создание DEBIAN/control..."
cat > "$DEBIAN_DIR/control" <<EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Architecture: $ARCH
Maintainer: Build System <build@example.com>
Description: jq - Command-line JSON processor ($BUILD_MODE build)
 jq is a lightweight and flexible command-line JSON processor.
 This is a $BUILD_MODE build with revision $REVISION.
EOF

# Перемещаем бинарник в стандартное место /usr/bin (если нужно)
# jq уже установлен в /usr/local/bin, оставляем как есть
# Но для стандартности deb-пакетов можно переместить в /usr/bin
if [ -f "$PACKAGE_DIR/usr/local/bin/jq" ]; then
    mkdir -p "$PACKAGE_DIR/usr/bin"
    cp "$PACKAGE_DIR/usr/local/bin/jq" "$PACKAGE_DIR/usr/bin/jq"
    log_info "Бинарник скопирован в /usr/bin"
fi

# Создаем deb-пакет
log_info "Создание deb-пакета..."
DEB_FILE="jq-${BUILD_MODE}_${JQ_VERSION}-${REVISION}_${ARCH}.deb"
OUTPUT_DIR="$(dirname "$STAGING_DIR")"

# Используем dpkg-deb для создания пакета
dpkg-deb --build "$PACKAGE_DIR" "$OUTPUT_DIR/$DEB_FILE"

if [ $? -eq 0 ] && [ -f "$OUTPUT_DIR/$DEB_FILE" ]; then
    log_info "deb-пакет успешно создан: $OUTPUT_DIR/$DEB_FILE"
    
    # Показываем информацию о пакете
    log_info "Информация о пакете:"
    dpkg-deb -I "$OUTPUT_DIR/$DEB_FILE" 2>/dev/null || true
else
    log_error "Ошибка при создании deb-пакета"
    exit 1
fi

# Очищаем временную директорию
rm -rf "$PACKAGE_DIR"

log_info "Создание deb-пакета завершено успешно"
