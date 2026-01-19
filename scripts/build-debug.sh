#!/bin/bash

# Скрипт сборки jq в режиме Debug
# Отладочные символы (-g)
# Без strip (сохранение отладочной информации)
# Установка в staging-директорию

# Предполагается запуск внутри Docker контейнера с рабочей директорией /build

set -e  # Остановка при ошибке

# Подключаем утилиты
# Внутри контейнера скрипт запускается из /build, поэтому используем относительный путь
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Рабочая директория (внутри контейнера это /build)
WORK_DIR="${WORK_DIR:-/build}"
cd "$WORK_DIR"

# Директория для артефактов Debug
ARTIFACTS_DIR="$WORK_DIR/artifacts/debug"
JQ_SRC_DIR="$WORK_DIR/jq-src-debug"
JQ_REPO_URL="https://github.com/jqlang/jq.git"

log_info "Начало сборки jq в режиме Debug"

# Шаг 1: Клонирование репозитория jq
log_info "Клонирование репозитория jq..."
if [ -d "$JQ_SRC_DIR" ]; then
    log_info "Директория $JQ_SRC_DIR уже существует, очищаем её"
    rm -rf "$JQ_SRC_DIR"
fi

git clone "$JQ_REPO_URL" "$JQ_SRC_DIR"
cd "$JQ_SRC_DIR"

# Переключаемся на стабильную ветку (master или main)
# Используем последний коммит из master
git checkout master 2>/dev/null || git checkout main 2>/dev/null || true

log_info "Репозиторий успешно клонирован"

# Шаг 2: Подготовка к сборке (autogen.sh для jq)
log_info "Подготовка к сборке (autogen.sh)..."
if [ -f "./autogen.sh" ]; then
    ./autogen.sh
else
    log_info "autogen.sh не найден, пропускаем этот шаг"
fi

# Шаг 3: Конфигурация сборки с отладочными символами
log_info "Конфигурация сборки с отладочными символами (-g)..."
# Устанавливаем флаги для отладки
export CFLAGS="-g"
export CXXFLAGS="-g"

# Запускаем configure с префиксом для установки
./configure --prefix=/usr/local

log_info "Конфигурация завершена"

# Шаг 4: Сборка проекта
log_info "Сборка проекта (make)..."
make -j$(nproc)

log_info "Сборка завершена"

# Шаг 5: Установка в staging-директорию
log_info "Установка в staging-директорию $ARTIFACTS_DIR..."
mkdir -p "$ARTIFACTS_DIR"
make install DESTDIR="$ARTIFACTS_DIR"

log_info "Установка завершена"

# В режиме Debug не выполняем strip, сохраняем отладочную информацию
log_info "Режим Debug: отладочные символы сохранены (strip не выполняется)"

# Проверка результата
JQ_BINARY="$ARTIFACTS_DIR/usr/local/bin/jq"
if [ -f "$JQ_BINARY" ]; then
    log_info "Проверка собранного бинарника:"
    "$JQ_BINARY" --version || true
    log_info "Бинарник находится в: $JQ_BINARY"
    
    # Проверяем наличие отладочных символов
    if command -v file >/dev/null 2>&1; then
        log_info "Информация о бинарнике:"
        file "$JQ_BINARY" || true
    fi
else
    log_error "Бинарник jq не найден в $JQ_BINARY"
    exit 1
fi

log_info "Сборка jq в режиме Debug успешно завершена"
log_info "Артефакты находятся в: $ARTIFACTS_DIR"
log_info "Отладочная информация сохранена в бинарнике"

# Шаг 6: Создание deb-пакета
log_info "Создание deb-пакета..."
"$SCRIPT_DIR/package-deb.sh" debug "$ARTIFACTS_DIR"

log_info "Сборка и упаковка в режиме Debug завершена"
