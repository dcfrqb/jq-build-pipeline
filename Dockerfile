# Dockerfile для образа сборки
# Содержит все необходимые инструменты для сборки проекта jq (C-проект)

FROM ubuntu:22.04

# Отключаем интерактивные диалоги при установке пакетов
ENV DEBIAN_FRONTEND=noninteractive

# Обновляем список пакетов и устанавливаем базовые инструменты сборки
RUN apt-get update && apt-get install -y \
    # Компилятор C
    gcc \
    # Инструмент сборки
    make \
    # Автоматизация сборки (нужна для многих C-проектов)
    autoconf \
    automake \
    libtool \
    # Git для клонирования репозиториев
    git \
    # pkg-config для работы с зависимостями
    pkg-config \
    # Инструменты для анализа покрытия кода
    lcov \
    gcov \
    # Инструменты для создания deb пакетов
    dpkg-dev \
    # Базовые утилиты
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Дополнительно: ccache для ускорения повторных сборок
# Он кэширует результаты компиляции, что ускоряет пересборку при изменении только части файлов
RUN apt-get update && apt-get install -y ccache && \
    rm -rf /var/lib/apt/lists/*

# Рабочая директория для сборки
WORKDIR /build

# По умолчанию запускаем bash
CMD ["/bin/bash"]
