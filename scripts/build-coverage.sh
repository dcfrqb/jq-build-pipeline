#!/bin/bash

# Скрипт сборки jq в режиме Coverage
# Инструменты gcov/lcov для анализа покрытия кода
# Интеграционное тестирование (jq --version)
# Проверка динамики покрытия по сравнению с предыдущим запуском
# Генерация отчета о покрытии

# Предполагается запуск внутри Docker контейнера с рабочей директорией /build

set -e  # Остановка при ошибке

# Подключаем утилиты
# Внутри контейнера скрипт запускается из /build, поэтому используем относительный путь
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Рабочая директория (внутри контейнера это /build)
WORK_DIR="${WORK_DIR:-/build}"
cd "$WORK_DIR"

# Директория для артефактов Coverage
ARTIFACTS_DIR="$WORK_DIR/artifacts/coverage"
JQ_SRC_DIR="$WORK_DIR/jq-src-coverage"
JQ_REPO_URL="https://github.com/jqlang/jq.git"
COVERAGE_PREVIOUS_FILE="$WORK_DIR/coverage_previous.txt"

log_info "Начало сборки jq в режиме Coverage"

# Шаг 1: Клонирование репозитория jq
log_info "Клонирование репозитория jq..."
if [ -d "$JQ_SRC_DIR" ]; then
    log_info "Директория $JQ_SRC_DIR уже существует, очищаем её"
    rm -rf "$JQ_SRC_DIR"
fi

git clone "$JQ_REPO_URL" "$JQ_SRC_DIR"
cd "$JQ_SRC_DIR"

# Переключаемся на стабильную ветку (master или main)
git checkout master 2>/dev/null || git checkout main 2>/dev/null || true

log_info "Репозиторий успешно клонирован"

# Шаг 2: Подготовка к сборке (autogen.sh для jq)
log_info "Подготовка к сборке (autogen.sh)..."
if [ -f "./autogen.sh" ]; then
    ./autogen.sh
else
    log_info "autogen.sh не найден, пропускаем этот шаг"
fi

# Шаг 3: Конфигурация сборки с флагами coverage
log_info "Конфигурация сборки с флагами coverage (--coverage)..."
# Устанавливаем флаги
export CFLAGS="--coverage"
export CXXFLAGS="--coverage"
export LDFLAGS="--coverage"

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

# Шаг 6: Интеграционное тестирование
log_info "Запуск интеграционного теста (jq --version)..."
JQ_BINARY="$ARTIFACTS_DIR/usr/local/bin/jq"
if [ ! -f "$JQ_BINARY" ]; then
    log_error "Бинарник jq не найден в $JQ_BINARY"
    exit 1
fi

# Запускаем простой тест
log_info "Выполнение теста: jq --version"
"$JQ_BINARY" --version
if [ $? -ne 0 ]; then
    log_error "Интеграционный тест не прошел"
    exit 1
fi
log_info "Интеграционный тест успешно выполнен"

# Шаг 7: Генерация отчета через lcov
log_info "Генерация coverage-отчета..."

# Переходим в директорию с исходниками для lcov
cd "$JQ_SRC_DIR"

# Собираем данные
log_info "Сбор coverage-данных (lcov --capture)..."
lcov --capture --directory . --output-file coverage.info

if [ ! -f "coverage.info" ]; then
    log_error "Не удалось создать coverage.info"
    exit 1
fi

# Удаляем системные пути из отчета
log_info "Очистка coverage-данных от системных путей..."
lcov --remove coverage.info '/usr/*' --output-file coverage.info

# Генерируем текстовый отчет
log_info "Генерация текстового отчета..."
lcov --list coverage.info > coverage_report.txt

# Извлекаем процент покрытия (используем lines coverage)
# lcov выводит строки вида "lines......: XX.X%"
COVERAGE_PERCENT=$(grep "lines\.\.\.\.\.\." coverage_report.txt | head -1 | awk '{print $2}' | sed 's/%//' || echo "0.0")

if [ -z "$COVERAGE_PERCENT" ] || [ "$COVERAGE_PERCENT" = "0.0" ]; then
    log_error "Не удалось извлечь процент покрытия"
    exit 1
fi

log_info "Текущее покрытие кода: ${COVERAGE_PERCENT}%"

# Шаг 8: Сравнение с предыдущим запуском
log_info "Сравнение с предыдущим запуском..."

# Получаем ревизию для имени файла отчета
REVISION=$(get_revision)
COVERAGE_REPORT_FILE="$ARTIFACTS_DIR/coverage_${REVISION}.txt"

# Сохраняем текущий отчет в файл с ревизией
echo "Coverage Report - Revision: $REVISION" > "$COVERAGE_REPORT_FILE"
echo "Date: $(date)" >> "$COVERAGE_REPORT_FILE"
echo "Coverage: ${COVERAGE_PERCENT}%" >> "$COVERAGE_REPORT_FILE"
echo "" >> "$COVERAGE_REPORT_FILE"
cat coverage_report.txt >> "$COVERAGE_REPORT_FILE"

log_info "Отчет сохранен в: $COVERAGE_REPORT_FILE"

# Проверяем наличие предыдущего файла
if [ ! -f "$COVERAGE_PREVIOUS_FILE" ]; then
    log_info "Предыдущий файл покрытия не найден - это первый запуск"
    log_info "Сохраняем текущее покрытие как базовое: ${COVERAGE_PERCENT}%"
    echo "$COVERAGE_PERCENT" > "$COVERAGE_PREVIOUS_FILE"
else
    # Читаем предыдущее покрытие
    PREVIOUS_COVERAGE=$(cat "$COVERAGE_PREVIOUS_FILE" | head -1 | awk '{print $1}')
    
    if [ -z "$PREVIOUS_COVERAGE" ]; then
        log_error "Не удалось прочитать предыдущее покрытие из $COVERAGE_PREVIOUS_FILE"
        exit 1
    fi
    
    log_info "Предыдущее покрытие: ${PREVIOUS_COVERAGE}%"
    log_info "Текущее покрытие: ${COVERAGE_PERCENT}%"
    
    # Сравниваем покрытие (используем bc для сравнения чисел с плавающей точкой)
    if command -v bc >/dev/null 2>&1; then
        # Если покрытие уменьшилось
        if (( $(echo "$COVERAGE_PERCENT < $PREVIOUS_COVERAGE" | bc -l) )); then
            log_error "Покрытие кода уменьшилось с ${PREVIOUS_COVERAGE}% до ${COVERAGE_PERCENT}%"
            log_error "Сборка завершается с ошибкой"
            exit 1
        else
            log_info "Покрытие кода не уменьшилось (было: ${PREVIOUS_COVERAGE}%, стало: ${COVERAGE_PERCENT}%)"
        fi
    else
        # Простое сравнение без bc (целые числа)
        PREVIOUS_INT=$(echo "$PREVIOUS_COVERAGE" | cut -d. -f1)
        CURRENT_INT=$(echo "$COVERAGE_PERCENT" | cut -d. -f1)
        
        if [ "$CURRENT_INT" -lt "$PREVIOUS_INT" ]; then
            log_error "Покрытие кода уменьшилось с ${PREVIOUS_COVERAGE}% до ${COVERAGE_PERCENT}%"
            log_error "Сборка завершается с ошибкой"
            exit 1
        else
            log_info "Покрытие кода не уменьшилось (было: ${PREVIOUS_COVERAGE}%, стало: ${COVERAGE_PERCENT}%)"
        fi
    fi
    
    # Обновляем файл предыдущего покрытия
    log_info "Обновление файла предыдущего покрытия..."
    echo "$COVERAGE_PERCENT" > "$COVERAGE_PREVIOUS_FILE"
fi

# Копируем coverage.info в артефакты
cp coverage.info "$ARTIFACTS_DIR/coverage_${REVISION}.info" 2>/dev/null || true

# Сохраняем процент покрытия в файл для использования в отчете
echo "$COVERAGE_PERCENT" > "$WORK_DIR/coverage_percent.txt"

log_info "Сборка jq в режиме Coverage успешно завершена"
log_info "Артефакты находятся в: $ARTIFACTS_DIR"
log_info "Покрытие кода: ${COVERAGE_PERCENT}%"
