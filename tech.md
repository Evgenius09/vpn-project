# tech.md — ядро проекта VPN-клиента

Версия ядра: **v25** (2026-11-03)
Владелец: тимлид. Файл меняется только append-only, только через PR с меткой `contract-change`. Каждое изменение контракта бампает версию и добавляет строку в changelog.

## Changelog

- v1 — 2026-11-01 — первая версия: продуктовые решения (дизайн 2, свайп), платформы Android и Windows, вход через Telegram-бота, стек, монорепо, контракты API v1 / TunnelRequest v1 / CoreEvent v1 / VpnApi v1 / IPC vpnsvc v1, схема БД, джобы River, UI-примитивы, тесты, слайсы стадий 0–5.
- v2 — 2026-11-01 — поправки §19: работа без серверов на стадии 0, порядок слайсов, GitHub Issues вместо Linear, источники `policy` и `endpoints`, типы настроек, `VpnBridge`, типы клиентов бэкенда, правила `verify` и начальное состояние автопереключения. §1–§18 не менялись; при расхождении прав §19.
- v3 — 2026-11-02 — §20: стадия 0 закрыта, метка `bootstrap` и её обработка в `contract-guard` удалены по §19.3. §1–§19 не менялись.
- v4 — 2026-11-02 — §21: формат ключей Reality, валидные ключи в фикстурах, уточнения сборки конфига для S1-01. §1–§20 не менялись.
- v5 — 2026-11-03 — §22: реализация `core/bind` в S1-02 без смены сигнатур, поведение операций ядра, перенос `URLTest` в S1-12, каталог данных `vpnsvc`. §1–§21 не менялись.
- v6 — 2026-11-03 — §23: `revoked` от хоста Android, последний запрос на Android, согласие на VPN в CI. §1–§22 не менялись.
- v7 — 2026-11-03 — §24: `syncRuleSets`, `listProcesses`, `last_request.json`, установщик. §1–§23 не менялись.
- v8 — 2026-11-03 — §25: `model` в `TelegramLoginStart` и `telegram_send_code`, лимит по IP, правила входа. §1–§24 не менялись.
- v9 — 2026-11-03 — §26: вход в `ApiClient` приложения, `DeviceIdentity`, `forgetLastRequest`, роуты входа и настроек, удаление `DEV_TOKEN`. §1–§25 не менялись.
- v10 — 2026-11-03 — §27: панель подключения на экранах режимов, значения `TunnelRequest` в приложении до S3-01. §1–§26 не менялись.
- v11 — 2026-11-03 — §28: выбор сервера на обоих экранах режимов, `selected` в `TunnelRequest`, `selectServer` из приложения. §1–§27 не менялись.
- v12 — 2026-11-03 — §29: параметры хоста панели, формат и проверка `servers.yaml`, правила `catalog_sync`, каталоги окружений. §1–§28 не менялись.
- v13 — 2026-11-03 — §30: место на диске и таймауты диагностики в CI эмулятора. §1–§29 не менялись.
- v14 — 2026-11-03 — §31: `URLTest` в ядре и `urlTest` по IPC, пинг и сортировка по пингу в приложении. §1–§30 не менялись.
- v15 — 2026-11-03 — §32: автопереключение в runtime и `core/bind`, причины смены режима, `Update` с состоянием автопереключения. §1–§31 не менялись.
- v16 — 2026-11-03 — §33: стрелки ← → на главном экране при фокусе вне `ModePager`, раскладка S2-01. §1–§32 не менялись.
- v17 — 2026-11-03 — §34: тумблер `whitelist.autoOnCellular` на экране «Белые списки» и в настройках, `update` при смене тумблера, реакция приложения на событие `mode`. §1–§33 не менялись.
- v18 — 2026-11-03 — §35: перебор `endpoints.api` в приложении, `ApiEndpoints` и `FallbackApiClient`, перенос rule sets из ассетов в S3-02. §1–§34 не менялись.
- v19 — 2026-11-03 — §36: staging на общем VPS: порт HTTPS, имя sslip.io, бот в polling, адрес хоста в секретах, вход в реестр образов. §1–§35 не менялись.
- v20 — 2026-11-03 — §37: сборка APK для staging по кнопке, раскладка S1-13 на одном сервере. §1–§36 не менялись.
- v21 — 2026-11-03 — §38: Xray на ноде закреплён на v26.6.27, Hysteria2 на staging, пароль Hysteria2 в Remnawave, webhook бота на staging, плейбук нод и смоук. §1–§37 не менялись.
- v22 — 2026-11-03 — §39: клиент Remnawave из OpenAPI 3.4.8, числовой id пользователя панели, поля Reality и Hysteria2 из API панели, squad новых пользователей, port hopping в `servers.yaml`, SSH-туннель к панели на staging. §1–§38 не менялись.
- v23 — 2026-11-03 — §40: TCP-стек `gvisor` на Android, слежение Android-хоста за физической сетью. §1–§39 не менялись.
- v24 — 2026-11-03 — §41: метаданные серверов из тегов и текстов хостов панели, удаление `servers.yaml` и `CATALOG_FILE`. §1–§40 не менялись.
- v25 — 2026-11-03 — §42: постоянный ключ подписи тестового APK, номер сборки, ядро только arm64 в `staging-apk`, пробный период 30 дней на staging. §1–§41 не менялись.

---

## 0. Как пользоваться файлом

- Это единственный источник истины. Всё, что здесь не определено, не существует. Нужного контракта нет → `CONTRACT GAP` (§13).
- Каждая сессия нейросети работает против конкретной версии ядра и указывает её в описании PR: `Core: tech.md v1`.
- Один слайс = одна задача = одна ветка = один PR. Карточки слайсов в §16.
- Эталонная вертикаль (§15.2) — шаблон структуры. Новый слайс повторяет её раскладку.

---

## 1. Проект

Собственный VPN-сервис: свои серверы, свой клиент, свой бэкенд поверх панели Remnawave, аккаунты через Telegram-бота.

- Для кого: пользователи в РФ, которым нужен стабильный доступ к заблокированным ресурсам, в том числе при ограничении мобильного интернета белыми списками.
- Цель: клиент уровня Happ по настройкам, проще по интерфейсу, плюс собственные фишки: автопереход на белые списки при смене Wi-Fi на мобильную сеть и сортировка по пингу.
- Протоколы: VLESS + Reality (TCP, flow `xtls-rprx-vision`) и Hysteria2.
- Платформы: **Android** и **Windows** (10 2004+ и 11, x64). Другие платформы вне плана.

---

## 2. Продуктовые решения (заморожены)

### 2.1 Главный экран: вариант дизайна 2 (свайп)

Два экрана-режима, переключаются горизонтальным свайпом (`ModePager`, §8):

| Индекс | Режим `TunnelMode` | Что на экране |
|---|---|---|
| 0 | `regular` | «Обычный VPN»: большая круглая кнопка `PowerButton`, статус, под ней `ServerSheet` со списком regular-серверов |
| 1 | `whitelist` | «Белые списки»: `PowerButton`, статус, `ServerSheet` со списком whitelist-серверов |

```
+--------------------------------+
| [настройки]     o .   [статус] |   PageDots: o = текущий экран
|                                |
|          Обычный VPN           |
|            (  O  )             |   PowerButton
|     Подключено  00:12:31       |
|                                |
| +---------- ServerSheet -----+ |   тянется вверх (DraggableScrollableSheet)
| | Серверы         [сорт:пинг]| |
| | DE Frankfurt      42 ms  * | |
| | NL Amsterdam      55 ms    | |
| +----------------------------+ |
+--------------------------------+
        <- свайп ->  экран «Белые списки»
```

Правила:
- **Свайп только переключает экран.** Свайп не меняет режим туннеля, не подключает и не отключает.
- Туннель один. Режим включается кнопкой `PowerButton` на экране этого режима.
- Состояние `PowerButton` на экране режима `P`:

| Туннель | Кнопка на экране `P` | Тап |
|---|---|---|
| отключён | `idle` | `start` с `userMode = P` |
| подключён, `effectiveMode == P` | `connected` | `stop` |
| подключён, `effectiveMode != P` | `idle`, подпись «Сейчас активен: <другой режим>» | `setUserMode(P)`: переключение без переподключения |
| `connecting` / `disconnecting` | то же состояние на обоих экранах | игнорируется |

- Автопереключение (§5.7) меняет `effectiveMode`. UI показывает `StatusBanner` с причиной и анимирует `ModePager` на экран `effectiveMode`.
- Выбранный сервер хранится отдельно для каждой группы.
- Windows: окно по умолчанию 420×760, минимум 360×640, контент по центру с максимальной шириной 480. Экраны переключаются перетаскиванием мышью, кликом по `PageDots` и клавишами ← →.

Визуальный дизайн придёт позже. Экраны собираются только из примитивов §8, все цвета, отступы, радиусы, шрифты — из токенов. Редизайн = замена токенов и примитивов, экраны не трогаются.

### 2.2 Аккаунты: Telegram-бот

Аккаунт выдаёт Telegram-бот. Пароли и email не используются.

1. Пользователь открывает бота и нажимает Start. Бот создаёт аккаунт, привязывает его к Telegram ID и запускает выдачу доступа в панели.
2. В приложении пользователь вводит свой Telegram-ник.
3. Бэкенд находит пользователя бота по нику и бот присылает 6-значный код.
4. Пользователь вводит код в приложении. Устройство привязывается к аккаунту, приложение получает токен.

Ограничения Telegram, которые обязан учитывать UI:
- Бот не может написать тому, кто его не запускал. Ник не найден → экран «Откройте бота и нажмите Start» с кнопкой-ссылкой на бота.
- У пользователя нет ника в Telegram → бот на `/start` просит задать ник в настройках Telegram.
- Ник меняется. Идентичность — Telegram ID; ник — последний известный, обновляется на каждом апдейте от пользователя.

Управление устройствами — командой бота `/devices` (стадия 4).

### 2.3 Наши фишки

| Фишка | Где | Ключ настройки |
|---|---|---|
| Автопереключение на белые списки при переходе Wi-Fi → мобильная сеть (тумблер) | ядро (§5.7) + мониторинг сети в хосте | `whitelist.autoOnCellular` |
| Сортировка серверов по пингу (тумблер) | app, чистая функция `sortServers` | `ui.sortByPing` |

### 2.4 Базовые фишки (перенос из Happ)

Клиентское ядро — sing-box, у Happ — Xray. Переносим только то, что sing-box реализует корректно против наших Xray-нод.

| Настройка Happ | Решение | Ключ |
|---|---|---|
| Маршрутизация вкл/выкл, профили правил | перенос | `routing.enabled`, `routing.preset` |
| Свои правила: домены, IP → proxy/direct/block | перенос | `routing.rules` |
| Прокси для выбранных приложений (on/bypass) | перенос: Android — пакеты, Windows — процессы | `perApp.mode`, `perApp.apps` |
| DNS удалённый/прямой | перенос | `dns.remote`, `dns.direct`, `dns.strategy` |
| IPv6 | перенос | `net.ipv6` |
| Sniffing | перенос | `net.sniffing` |
| Фрагментация TLS | перенос через `tls.fragment` / `tls.record_fragment` sing-box | `net.tlsFragment` |
| MTU туннеля | перенос | `net.mtu` |
| Режим TUN (system/gvisor/mixed) | перенос | `net.tunStack` |
| Exclude routes, обход локальной сети | перенос | `net.excludeRoutes`, `net.bypassLan` |
| Режим Proxy / TUN на десктопе | только TUN | — |
| Тип пинга, URL проверки, таймаут, пинг при открытии | перенос: `tcp` и `url_test`; ICMP нет | `ping.*` |
| Автоподключение при запуске (last used / lowest ping / random) | перенос | `connect.autoConnect`, `connect.autoConnectStrategy` |
| Автозапуск | Android — при загрузке устройства; Windows — при входе в систему | `connect.autostart` |
| Строка трафика и срока, объявления, ссылка поддержки | перенос | приходят в `ProfileV1` |
| Сортировка серверов | перенос (наша фишка) | `ui.sortByPing` |
| Язык, тема светлая/тёмная/системная | перенос | `ui.locale`, `ui.theme` |
| Mux (Xray mux.cool) | **не переносим**: sing-box multiplex несовместим с Xray-сервером, Vision не работает с mux | — |
| Noises, XHTTP, No Limit Mode, Xray TUN, выбор ядра туннеля | **не переносим**: фичи Xray | — |
| Скрыть иконку VPN | **не переносим** | — |

Настройки, которые провайдер задаёт по умолчанию или блокирует, приходят в `ClientPolicy` (§5.3).

---

## 3. Стек и версии

| Слой | Технология |
|---|---|
| Клиент UI | Flutter (stable), Dart, Riverpod, go_router, gen-l10n (ru, en), flutter_secure_storage |
| Клиент Windows (desktop-обвязка) | Flutter Windows; tray_manager, window_manager, launch_at_startup; пакет `win32` (FFI) для named pipe |
| Клиент Android | Kotlin, `VpnService`, foreground service |
| Мост Flutter ↔ Android | Pigeon (`contracts/pigeon/vpn_api.dart`) |
| Мост Flutter ↔ Windows | JSON-RPC 2.0 по named pipe к службе `vpnsvc` (§5.6) |
| Ядро туннеля | Go-модуль `core`: sing-box + наша логика. Android: `gomobile bind` → `.aar` (libbox). Windows: служба `vpnsvc.exe` (Go, `golang.org/x/sys/windows/svc`), wintun |
| Установщик Windows | Inno Setup: app + `vpnsvc.exe` + регистрация службы |
| Бэкенд | Go, chi, pgx, sqlc, PostgreSQL, River (очередь на Postgres), goose (миграции), oapi-codegen |
| Telegram-бот | Go внутри бэкенда, `github.com/go-telegram/bot`; webhook на staging/prod, long polling в dev |
| Контракты | OpenAPI 3.1 (`contracts/openapi.yaml`) → Go (oapi-codegen), Dart (swagger_parser) |
| VPN-серверы | Remnawave panel + Remnawave node (Xray-core): VLESS Reality Vision, Hysteria2 |
| Инфраструктура | Docker Compose, Ansible, Caddy (TLS для API и webhook), GitHub Actions |
| Мониторинг | Prometheus, Grafana, node_exporter, blackbox_exporter |
| Тесты Go | `testing`, testify/require, `pgregory.net/rapid` (property-based), kin-openapi (валидация ответов) |
| Тесты Dart | flutter_test, mocktail, glados (property-based), golden-тесты, integration_test |
| Тесты натива | JUnit (Android), Go-тесты `vpnsvc` на windows-раннере |

Версии:
- Все тулчейны фиксируются в `.tool-versions` (mise): Go, Flutter, Dart, Java, gomobile, sqlc, goose, oapi-codegen, Inno Setup.
- sing-box: ветка **1.14.x**, точный тег в `core/go.mod`. Апгрейд ветки = контрактное изменение, потому что меняется формат опций. Build tags для Android (libbox) и Windows (tun, wintun, quic, utls) — по upstream release build, фиксируются в `core/Makefile`.
- Remnawave: точная версия образов panel и node в `infra/compose/remnawave/`. Go-клиент панели генерится из её OpenAPI этой версии. Апгрейд панели = контрактное изменение.
- Перед включением Hysteria2 проверить версию Xray в образе ноды и известные баги статистики Hysteria inbound.

---

## 4. Архитектура

### 4.1 Компоненты

```
 Flutter app (Dart)                            Backend (Go)
 - UI, состояние, настройки                    - api: chi, oapi-codegen strict server
 - вход через Telegram  ---- HTTPS ---->       - bot: Telegram webhook / polling
 - API-клиент (generated)                      - worker: River jobs
 - TCP-пинг, собирает TunnelRequest            - PanelClient (Remnawave | fake)
 - VpnBridge: Pigeon | Pipe | Fake             - TelegramClient (Bot API | fake)
     |                     |                   - PostgreSQL
     | Pigeon              | named pipe              |          ^
     v                     v JSON-RPC                v REST     | Bot API
 Android host          Windows service           Remnawave      Telegram
 TunnelService         vpnsvc.exe (SYSTEM)       panel
 (VpnService)          wintun                      |
     | gomobile            |                       v
     v                     v                     Remnawave nodes (Xray)
 core (Go): sing-box + ConfigBuilder             - VLESS Reality Vision :443/tcp
 + autoswitch + url_test                          - Hysteria2 :udp (port hopping)
```

Распределение логики:
- Сборка конфига sing-box и автопереключение — в `core`, одна реализация на обе платформы, типизированные опции sing-box.
- Android-хост тонкий: жизненный цикл туннеля, разрешение VPN, уведомление, тип сети.
- Windows-служба `vpnsvc` — тот же `core` плюс IPC-сервер, мониторинг сети и хранение последнего `TunnelRequest` для автозапуска. Работает от SYSTEM, потому что TUN требует прав администратора. UI работает от обычного пользователя.
- Dart: UI, состояние, настройки, API, вход, TCP-пинг, сортировка. Платформенный мост скрыт за `VpnBridge` (`app/lib/core/vpn/`).

### 4.2 Поток подключения

1. App: `GET /v1/profile` с `If-None-Match` → кэш профиля на диске.
2. Тап `PowerButton` → `VpnBridge.prepare()` (Android: разрешение VPN; Windows: служба установлена и запущена) → app собирает `TunnelRequest` (§5.4) → `VpnBridge.start(json)`.
3. Хост → `core.Start(json)` → валидация → `BuildOptions` → `box.New` → старт.
4. Ядро шлёт `CoreEvent` (JSON) → хост → Pigeon event stream или pipe-нотификация → app.
5. Смена сервера или режима при подключённом туннеле → `selectServer` / `setUserMode` → переключение селектора без рестарта.
6. Смена настроек туннеля → `update(json)` → ядро пересобирает конфиг и перезапускает box.

### 4.3 Структура монорепо

```
/
├── tech.md                     # ядро (тимлид)
├── CLAUDE.md                   # авто-подгрузка ядра
├── .tool-versions
├── Makefile                    # make gen | check | test | seed | dev
├── contracts/                  # тимлид
│   ├── openapi.yaml            # HTTP API + все общие типы (components/schemas)
│   ├── pigeon/vpn_api.dart     # мост Flutter <-> Android
│   └── fixtures/               # профили, TunnelRequest, CoreEvent, IPC-сессии (.jsonl), seed
├── backend/
│   ├── cmd/{api,worker,bot,migrate,seed}/main.go   # bot: long polling для dev
│   └── internal/
│       ├── config/             # тимлид: env -> Config
│       ├── httpapi/            # тимлид: роутер, middleware, problem+json
│       ├── gen/{api,remnawave}/   # generated, руками не править
│       ├── db/migrations/      # тимлид: goose SQL
│       ├── db/queries/<domain>.sql  # владелец слайса
│       ├── db/sqlc/            # generated
│       ├── jobs/               # тимлид: River client, реестр kind'ов и args
│       ├── panel/              # тимлид: PanelClient interface + fake; remnawave impl — слайс S1-10
│       ├── telegram/           # тимлид: TelegramClient interface + fake; botapi impl — слайс S1-05
│       ├── domain/<domain>/    # слайсы: service.go, handler.go, store.go, *_test.go
│       └── testutil/           # тимлид
├── core/
│   ├── bind/                   # тимлид: gomobile-поверхность (Android)
│   ├── cmd/vpnsvc/             # Windows-служба
│   ├── internal/contract/      # generated из openapi.yaml (types only)
│   ├── internal/config/        # ConfigBuilder
│   ├── internal/autoswitch/    # state machine
│   ├── internal/runtime/       # жизненный цикл box, события
│   ├── internal/ipc/           # JSON-RPC сервер vpnsvc (протокол платформонезависим)
│   ├── internal/urltest/
│   └── Makefile                # gomobile bind, сборка vpnsvc, build tags
├── app/
│   ├── lib/
│   │   ├── app/                # тимлид: bootstrap, router, shell, навигация-данные
│   │   ├── ui/                 # тимлид: токены, тема, примитивы
│   │   ├── core/               # тимлид: DI, storage, api client wiring, vpn/ (VpnBridge + реализации)
│   │   ├── gen/                # generated (api, pigeon), руками не править
│   │   ├── l10n/               # arb: ru, en
│   │   └── features/<feature>/{data,domain,application,presentation}/
│   ├── android/                # Kotlin host (TunnelService)
│   ├── windows/                # Flutter Windows runner (не трогать без нужды)
│   ├── env/{dev,staging,prod}.json
│   └── test/ integration_test/
├── installer/windows/          # Inno Setup скрипт
├── infra/
│   ├── ansible/                # роли: api-host, remnawave-panel, remnawave-node, monitoring
│   ├── compose/                # api, worker, postgres, caddy; remnawave
│   ├── catalog/servers.yaml    # метаданные серверов (группа, страна, вес)
│   └── monitoring/             # prometheus rules, grafana dashboards
└── .github/workflows/          # тимлид
```

---

## 5. Контракты

### 5.1 Владение

Контрактные пути (правка только тимлидом, только PR с меткой `contract-change` и бампом версии ядра):
`tech.md`, `contracts/**`, `backend/internal/db/migrations/**`, `backend/internal/jobs/**`, `backend/internal/panel/panel.go`, `backend/internal/telegram/telegram.go`, `backend/internal/config/**`, `backend/internal/httpapi/**`, `core/bind/**`, `core/internal/ipc/protocol.go`, `app/lib/ui/**`, `app/lib/app/**`, `app/lib/core/**`, `installer/**`, `.github/**`, `infra/**`, `.tool-versions`, `Makefile`.

Generated-пути (`*/gen/**`, `backend/internal/db/sqlc/**`, `core/internal/contract/**`) руками не правятся никем. Только `make gen`.

Все общие типы определены один раз в `contracts/openapi.yaml#/components/schemas`. Go-типы бэкенда, Go-типы ядра и Dart-модели генерятся оттуда. Ниже — нормативное описание этих схем; `openapi.yaml` обязан ему соответствовать.

### 5.2 HTTP API v1

База: `https://<api-domain>/v1`. JSON, camelCase, время в RFC 3339 UTC.

Авторизация: `Authorization: Bearer <deviceToken>`. Токен — 32 случайных байта в base64url. В БД хранится `HMAC-SHA256(token, TOKEN_PEPPER)`.

Ошибки: `application/problem+json` (RFC 9457) с обязательным полем `code`:
`unauthorized | device_revoked | validation_failed | rate_limited | telegram_user_not_found | code_invalid | code_expired | device_limit_reached | panel_unavailable | not_found | internal`.
Дополнительные поля проблемы: `botUrl` (для `telegram_user_not_found`), `attemptsLeft` (для `code_invalid`), `retryAfterSec` (для `rate_limited`).

| Метод | Путь | Auth | Назначение |
|---|---|---|---|
| POST | `/v1/auth/telegram/start` | нет, rate limit | запросить код в боте |
| POST | `/v1/auth/telegram/verify` | нет, rate limit | обменять код на токен устройства |
| POST | `/v1/auth/logout` | да | отозвать текущее устройство |
| GET | `/v1/profile` | да | профиль: аккаунт, серверы, политика, эндпоинты |
| GET | `/v1/rulesets/{id}.srs` | да | rule set sing-box (может отдаваться Caddy статикой) |
| POST | `/telegram/webhook` | заголовок `X-Telegram-Bot-Api-Secret-Token` | апдейты Telegram (вне `/v1`, вне `openapi.yaml`) |
| GET | `/healthz` | нет | liveness |
| GET | `/metrics` | только внутренняя сеть | Prometheus |

`POST /v1/auth/telegram/start`
- Request `TelegramLoginStart`: `username: string` (с `@` или без, нормализуется: без `@`, нижний регистр, `^[a-z0-9_]{5,32}$`), `installId: uuid`.
- Response 200 `TelegramLoginChallenge`: `loginId: uuid`, `expiresAt: datetime`, `resendAfterSec: int`, `botUrl: string`.
- Ник не найден среди пользователей бота или бот заблокирован пользователем → 404 `telegram_user_not_found` с `botUrl`.
- Код отправляется джобом `telegram_send_code` (§7). Новый `start` для того же `telegram_id` и `installId` инвалидирует прежний неиспользованный код.
- Лимиты: повтор не раньше `resendAfterSec` (60 с), не больше 5 кодов в час на Telegram ID, не больше `AUTH_RATE_PER_MIN` запросов с IP.

`POST /v1/auth/telegram/verify`
- Request `TelegramLoginVerify`: `loginId: uuid`, `code: string` (6 цифр), `installId: uuid`, `platform: Platform`, `model: string`, `appVersion: string`.
- Response 200 `AuthResult`: `deviceId: uuid`, `accountId: uuid`, `token: string`.
- Код живёт 5 минут, 5 попыток. Неверный → 400 `code_invalid` с `attemptsLeft`; истёк или попытки кончились → 410 `code_expired`.
- Устройство с этим `installId` уже есть → тот же `deviceId`, новый токен, старый перестаёт работать. Иначе новое устройство; активных устройств уже `device_limit` → 409 `device_limit_reached`.
- Код одноразовый: после успеха `consumed_at` выставлен, повтор → `code_expired`.

`GET /v1/profile`
- Поддерживает `ETag` / `If-None-Match` → 304.
- Response 200 `ProfileV1`. Пока `panel_provision_user` не завершён: `account.status = provisioning`, `servers = []`, заголовок `Retry-After: 2`.
- Аккаунт `expired` или `blocked`: 200, `servers = []`.
- Отозванное устройство → 401 `device_revoked`; app удаляет токен и показывает экран входа.

### 5.3 Общие типы

```
TunnelMode        = regular | whitelist
ServerProtocol    = vless_reality | hysteria2
Platform          = android | windows
AccountStatus     = provisioning | trial | active | expired | blocked

ServerNode
  id: string                 # uuid из БД
  group: TunnelMode
  name: string
  countryCode?: string       # ISO 3166-1 alpha-2, верхний регистр
  city?: string
  protocol: ServerProtocol
  address: string            # домен или IP
  port: int                  # 1..65535
  vless?: VlessRealityParams        # обязателен при protocol = vless_reality
  hysteria2?: Hysteria2Params       # обязателен при protocol = hysteria2
  sortWeight: int            # из каталога

VlessRealityParams
  uuid: string               # секрет
  flow: "xtls-rprx-vision" | ""
  serverName: string         # SNI
  publicKey: string
  shortId: string
  fingerprint: chrome | firefox | safari | ios | android | edge | random

Hysteria2Params
  password: string           # секрет
  serverName: string
  obfsSalamanderPassword?: string
  portHopping?: { ports: string, intervalSec: int }   # ports: "20000-30000" или "443,8443"
  upMbps?: int
  downMbps?: int

AccountInfo
  status: AccountStatus
  telegramUsername?: string
  expiresAt?: datetime
  trafficUsedBytes: int64
  trafficLimitBytes: int64   # 0 = без лимита
  deviceLimit: int

ProfileV1
  schemaVersion: 1
  generatedAt: datetime
  account: AccountInfo
  servers: ServerNode[]      # обе группы
  policy: ClientPolicy
  endpoints: { api: string[], bot: string, support?: string, web?: string }   # api[0] основной, далее fallback
  announcement?: { text: string, level: info | warning, actionLabel?: string, actionUrl?: string }

ClientPolicy
  defaults: SettingsPatch    # значения для незаблокированных ключей без пользовательского значения
  locked: SettingsKey[]      # пользователь не меняет эти ключи
  flags: { autoWhitelist: bool }
  ping: { url: string, timeoutMs: int }
  ruleSets: RuleSetRef[]
  minAppVersion: { android: string, windows: string }   # semver; ниже — экран «обновите приложение»
  appUpdate?: { android?: AppRelease, windows?: AppRelease }

AppRelease
  version: string            # semver
  url: string                # APK / установщик Windows
  sha256: string
  notes?: string

RuleSetRef
  id: string                 # ru-direct, ads, ...
  url: string
  sha256: string

SettingsKey (строковый enum, путь к полю)
  routing.enabled, routing.preset, routing.rules,
  dns.remote, dns.direct, dns.strategy,
  net.ipv6, net.sniffing, net.tlsFragment, net.mtu, net.tunStack, net.excludeRoutes, net.bypassLan,
  perApp.mode, perApp.apps,
  ping.type, ping.url, ping.timeoutMs, ping.onOpen,
  connect.autoConnect, connect.autoConnectStrategy, connect.autostart,
  ui.sortByPing, ui.locale, ui.theme,
  whitelist.autoOnCellular

SettingsPatch — объект с теми же путями, все поля опциональны.
```

Клиентские настройки (только Dart, в `TunnelRequest` не уходят): `ui.*`, `ping.*`, `connect.*`. Остальные уходят в `TunnelSettings`.

### 5.4 TunnelRequest v1 (app → core)

Передаётся как JSON-строка. Ядро валидирует и отвергает с `config_invalid`.

```
TunnelRequest
  schemaVersion: 1
  platform: Platform
  userMode: TunnelMode
  selected: { regular?: string, whitelist?: string }   # serverId
  servers: ServerNode[]
  autoSwitch: { enabled: bool }
  settings: TunnelSettings
  log: { level: warn | info | debug }

TunnelSettings
  routing:
    enabled: bool
    preset: ru_direct | all_proxy | custom
    rules: RoutingRule[]         # применяются по порядку, до правил пресета
    ruleSets: LocalRuleSet[]     # app скачивает .srs заранее, ядро читает локально
  dns:
    remote: string               # DoH URL, через proxy
    direct: string               # DoH URL или IP, напрямую
    strategy: prefer_ipv4 | prefer_ipv6 | ipv4_only | ipv6_only
  net:
    ipv6: bool
    sniffing: bool
    tlsFragment: { enabled: bool, record: bool }
    mtu: int                     # 1280..9000, по умолчанию 1500
    tunStack: system | gvisor | mixed
    excludeRoutes: string[]      # CIDR
    bypassLan: bool
  perApp:
    mode: off | include | exclude
    apps: string[]               # Android: имена пакетов; Windows: имена процессов (*.exe)

RoutingRule
  id: string
  match: domain | domain_suffix | domain_keyword | ip_cidr | rule_set | app
  value: string                  # для app: пакет на Android, процесс на Windows
  action: proxy | direct | block

LocalRuleSet
  id: string
  path: string                   # Android: путь в контейнере приложения; Windows: путь в %ProgramData%\<app>\rulesets
```

На Windows app не передаёт службе файлы напрямую: rule sets скачивает служба по `RuleSetRef` из `policy` и кладёт в свой каталог. App передаёт в `LocalRuleSet.path` только `id`-относительный путь `rulesets/<id>.srs`; служба резолвит его в своём каталоге.

### 5.5 CoreEvent v1 (core → app)

Плоский конверт, чтобы генераторы не спотыкались на `oneOf`. Заполнено ровно одно поле-нагрузка, соответствующее `type`.

```
CoreEvent
  type: state | mode | traffic | url_test | error
  at: datetime
  state?:   { status: TunnelStatus, userMode: TunnelMode, effectiveMode: TunnelMode,
              activeServerId?: string, connectedSince?: datetime }
  mode?:    { from: TunnelMode, to: TunnelMode, reason: ModeSwitchReason }
  traffic?: { upBps: int64, downBps: int64, upTotal: int64, downTotal: int64 }
  urlTest?: { results: [{ serverId: string, delayMs?: int, error?: string }] }
  error?:   { code: CoreErrorCode, message: string }

TunnelStatus     = disconnected | connecting | connected | disconnecting | error
ModeSwitchReason = user | network_cellular | network_wifi | override_cleared | no_whitelist_servers
CoreErrorCode    = config_invalid | start_failed | no_servers_in_group | permission_denied
                 | tun_failed | revoked | service_unavailable | ipc_version_mismatch | internal
```

`traffic` шлётся раз в 1 секунду только в `connected`. `state` шлётся на каждое изменение и в ответ на `getState`.

### 5.6 Мосты к ядру

Dart-абстракция `VpnBridge` (`app/lib/core/vpn/vpn_bridge.dart`, тимлид) с методами, совпадающими с `VpnHostApi` ниже, и потоком `Stream<CoreEvent>`. Реализации: `PigeonVpnBridge` (Android), `PipeVpnBridge` (Windows), `FakeVpnBridge` (тесты, `FAKE_VPN=true`). Фичи зависят только от `VpnBridge`.

**Android: Pigeon (`contracts/pigeon/vpn_api.dart`)**

```dart
enum TunnelModeMsg { regular, whitelist }
enum PrepareResult { granted, denied }

@HostApi()
abstract class VpnHostApi {
  @async PrepareResult prepare();                 // VpnService.prepare
  @async void start(String tunnelRequestJson);
  @async void update(String tunnelRequestJson);   // смена настроек, рестарт box
  @async void stop();
  @async void setUserMode(TunnelModeMsg mode);
  @async void selectServer(TunnelModeMsg group, String serverId);
  @async String urlTest(List<String> serverIds);  // JSON CoreEvent type=url_test; только в connected
  @async String getState();                       // JSON CoreEvent type=state
  @async List<String> listApps();                 // JSON {package, label} для выбора приложений
}

@EventChannelApi()
abstract class VpnEventApi {
  String events();                                // поток JSON CoreEvent
}
```

Ошибки `start/update` пробрасываются как `PlatformException(code: CoreErrorCode)`.

**Windows: IPC vpnsvc v1**

- Транспорт: named pipe `\\.\pipe\<app-id>-core`. ACL: SYSTEM и Administrators — полный доступ, Authenticated Users — чтение и запись.
- Кадрирование: JSON-RPC 2.0, одно сообщение на строку (`\n`), UTF-8, максимум 4 MiB на сообщение.
- Первый вызов обязателен: `hello { protocolVersion: 1, appVersion }` → `{ protocolVersion: 1, serviceVersion }`. Несовпадение версий → ошибка `ipc_version_mismatch`.
- Методы (params → result):

| Метод | Params | Result |
|---|---|---|
| `hello` | `{protocolVersion, appVersion}` | `{protocolVersion, serviceVersion}` |
| `prepare` | `{}` | `{result: granted}` (служба доступна) |
| `start` | `{tunnelRequest: TunnelRequest}` | `{}` |
| `update` | `{tunnelRequest: TunnelRequest}` | `{}` |
| `stop` | `{}` | `{}` |
| `setUserMode` | `{mode}` | `{}` |
| `selectServer` | `{group, serverId}` | `{}` |
| `urlTest` | `{serverIds}` | `CoreEvent` (`url_test`) |
| `getState` | `{}` | `CoreEvent` (`state`) |
| `syncRuleSets` | `{ruleSets: RuleSetRef[]}` | `{ready: string[]}` |
| `listProcesses` | `{}` | `[{name, path}]` запущенных процессов для выбора приложений |
| `subscribe` | `{}` | `{}`; дальше служба шлёт нотификации `event` с `params: CoreEvent` |

- Ошибки JSON-RPC: `error.code = -32000`, `error.data.code: CoreErrorCode`.
- Служба не отвечает или не установлена → `PipeVpnBridge` отдаёт `service_unavailable`; UI показывает инструкцию переустановить приложение.
- Служба хранит последний принятый `TunnelRequest` в `%ProgramData%\<app>\last_request.json` (ACL только SYSTEM и Administrators) для автоподключения при старте системы.
- Протокол реализован платформонезависимо в `core/internal/ipc` поверх `io.ReadWriteCloser`; pipe-транспорт — тонкая обёртка `go-winio`.

### 5.7 Автопереключение на белые списки: спецификация

Реализация: `core/internal/autoswitch`, чистая функция `Next(State, Event) (State, []Action)`.

```
NetType = wifi | cellular | ethernet | other | none

State
  net: NetType
  userMode: TunnelMode
  autoSwitch: bool
  override: bool              # пользователь сам выбрал режим в текущей сети
  whitelistAvailable: bool    # в запросе есть хотя бы один сервер группы whitelist
  effective: TunnelMode

Event = NetChanged(NetType) | UserModeSet(TunnelMode) | AutoSwitchSet(bool) | ServersUpdated(whitelistAvailable)
Action = SelectGroup(TunnelMode) | Emit(ModeEvent)
```

`UserModeSet` приходит только из тапа по `PowerButton` (§2.1). Свайп событий не порождает.

Правило вычисления `effective`:
1. `autoSwitch == false` → `userMode`.
2. `override == true` → `userMode`.
3. `net == cellular && whitelistAvailable` → `whitelist`.
4. Иначе → `userMode`.

Переходы:
- `NetChanged(t)`: `t == none` → состояние не меняется. Иначе `t != net` → `override = false`, `net = t`.
- `UserModeSet(m)`: `userMode = m`; если `autoSwitch && net == cellular` → `override = true`.
- `AutoSwitchSet(b)`: `autoSwitch = b`, `override = false`.
- `ServersUpdated(w)`: `whitelistAvailable = w`.
- После любого события: если `effective` изменился → `SelectGroup(effective)` и `Emit(ModeEvent)` с причиной: `network_cellular`, `network_wifi` (для wifi/ethernet/other), `user`, `override_cleared`. Правило 3 не сработало из-за `whitelistAvailable == false` на cellular → `Emit` с `no_whitelist_servers` без смены группы.

Инварианты (property-based тесты, rapid):
- I1. `autoSwitch == false` ⇒ `effective == userMode` после любой последовательности.
- I2. Ядро никогда не выбирает `whitelist` автоматически при `whitelistAvailable == false`.
- I3. `wifi → cellular → wifi` без пользовательских событий ⇒ `effective == userMode`.
- I4. `NetChanged(none)` не меняет состояние.
- I5. Детерминизм: одинаковая последовательность событий → одинаковое состояние и действия.
- I6. Повторное одинаковое событие не порождает действий.

Источник `NetChanged`, debounce 1 секунда в хосте:
- Android: `ConnectivityManager.NetworkCallback` в `TunnelService`, транспорт активной сети → `NetType`.
- Windows: `vpnsvc` подписывается на изменения сети (`NotifyNetworkConnectivityHintChange`). `cellular`, если активный интерфейс WWAN или стоимость подключения не `unrestricted` (лимитная сеть: раздача с телефона). Иначе `wifi` / `ethernet` по типу интерфейса. Интерфейс wintun при определении игнорируется.

### 5.8 Сборка конфига sing-box (`core/internal/config`)

`BuildOptions(TunnelRequest) (option.Options, error)` — чистая функция на типизированных опциях sing-box.

Теги и структура:
- Outbound на каждый сервер: `srv-<serverId>`.
- Селекторы `grp-regular` и `grp-whitelist` по группе сервера. Пустая группа не создаётся.
- Селектор `proxy`: `[grp-regular, grp-whitelist]`, default = `effective`, `interrupt_exist_connections: true`.
- `direct`. Блокировка — rule action `reject`, не outbound.
- `route.final = proxy`.
- Порядок правил: `sniff` (если `net.sniffing`) → `hijack-dns` для DNS → `bypassLan` (private IP → direct) → адреса всех серверов → direct → пользовательские `routing.rules` по порядку → правила пресета → final.
- DNS: только новый формат серверов (1.12+), legacy-поля запрещены. `remote` через `proxy`, `direct` через `direct`. `strategy` из настроек; `ipv6 == false` форсирует `ipv4_only`.
- Inbound `tun`: адрес `172.19.0.1/30` (+ `fdfe:dcba:9876::1/126` при `ipv6`), `mtu`, `stack`, `auto_route`, `strict_route`.
- `perApp`:
  - Android: `include_package` / `exclude_package` на tun; собственный пакет приложения всегда в `exclude_package`.
  - Windows: `route.find_process: true`; `include` → правило `process_name ∈ apps → proxy` и `final = direct`; `exclude` → правило `process_name ∈ apps → direct`. Правило `match: app` в `routing.rules` → `process_name` на Windows, `package_name` на Android.
- VLESS: `flow` из параметров, `packet_encoding: xudp`, `tls.reality`, `utls.fingerprint`. `multiplex` на VLESS не включается никогда.
- Hysteria2: `server_ports` и `hop_interval` из `portHopping`, `obfs.salamander`, `tls.server_name`.
- `tlsFragment.enabled` → `tls.fragment: true` на TLS-outbound'ах; совместимость с Reality фиксируется ADR в S3-04. `record` → `tls.record_fragment`.
- `experimental.cache_file` включён в рабочей директории ядра.

Инварианты (rapid):
- C1. Любой валидный `TunnelRequest` даёт опции, которые проходят `box.New` без ошибок (эквивалент `sing-box check`) для обеих платформ.
- C2. Каждый сервер из запроса имеет ровно один outbound `srv-*`, и он входит ровно в одну группу, совпадающую с `group`.
- C3. `selected.*`, указывающий на отсутствующий сервер, → первый сервер группы по `sortWeight`, без ошибки.
- C4. Адрес каждого сервера маршрутизируется в `direct`.
- C5. `platform = windows` ⇒ нет `include_package` / `exclude_package`; `platform = android` ⇒ нет `process_name`.
- C6. Секреты (`uuid`, `password`) не появляются в логах ядра.

### 5.9 Поверхность core

Android (`core/bind`, gomobile: только базовые типы, строки, интерфейсы):

```go
type EventSink interface { OnEvent(coreEventJSON string) }

func NewCore(platform libbox.PlatformInterface, sink EventSink, workDir string) *Core
func (c *Core) Start(tunnelRequestJSON string) error
func (c *Core) Update(tunnelRequestJSON string) error
func (c *Core) Stop() error
func (c *Core) SetUserMode(mode string) error           // "regular" | "whitelist"
func (c *Core) SelectServer(group, serverID string) error
func (c *Core) OnNetworkChanged(netType string)          // NetType
func (c *Core) URLTest(serverIDsJSON string) (string, error)   // JSON CoreEvent url_test
func (c *Core) State() string                            // JSON CoreEvent state
```

Kotlin-хост реализует `libbox.PlatformInterface` по образцу официального Android-клиента sing-box.

Windows: `core/cmd/vpnsvc` использует `core/internal/runtime` напрямую (без gomobile) и `core/internal/ipc`. Набор операций runtime тот же, что у `bind.Core`.

### 5.10 Внешние клиенты бэкенда

**PanelClient (`backend/internal/panel/panel.go`)**

```go
type PanelUser struct {
    UUID          uuid.UUID
    ShortUUID     string
    Username      string
    ExpiresAt     time.Time
    TrafficLimit  int64
    TrafficUsed   int64
    VlessUUID     string // секрет
    Hysteria2Auth string // секрет
}

type PanelHost struct {
    UUID     uuid.UUID
    Protocol string // vless_reality | hysteria2
    Address  string
    Port     int
    Params   json.RawMessage // несекретные параметры inbound/host
    Enabled  bool
}

type PanelClient interface {
    GetUserByUsername(ctx context.Context, username string) (PanelUser, error) // ErrNotFound
    CreateUser(ctx context.Context, in CreateUserInput) (PanelUser, error)     // ErrConflict, если username занят
    UpdateUser(ctx context.Context, uuid uuid.UUID, in UpdateUserInput) (PanelUser, error)
    ListHosts(ctx context.Context) ([]PanelHost, error)
}
```

- Username в панели: `tg_<telegram_id>`.
- Ошибки: `panel.ErrNotFound`, `panel.ErrConflict`, `panel.ErrUnavailable` (5xx, таймаут, сеть).
- Реализации: `panel/fake` (сид-данные, программные сбои `FailNext(op, err)`), `panel/remnawave` (generated-клиент).
- Откуда брать `Hysteria2Auth` и параметры Reality из API панели — решается в S1-10 по OpenAPI зафиксированной версии, записывается ADR + бампом ядра.

**TelegramClient (`backend/internal/telegram/telegram.go`)**

```go
type Update struct {
    UpdateID   int64
    TelegramID int64
    ChatID     int64
    Username   string // без @, нижний регистр; "" если ника нет
    FirstName  string
    Text       string // текст сообщения или команда
    CallbackData string
}

type TelegramClient interface {
    SendMessage(ctx context.Context, chatID int64, text string, buttons []InlineButton) (messageID int64, err error)
    AnswerCallback(ctx context.Context, callbackID string, text string) error
}
// Ошибки: telegram.ErrBotBlocked (пользователь заблокировал бота, 403), telegram.ErrUnavailable (5xx, сеть, 429)
```

- Реализации: `telegram/botapi` (поверх `go-telegram/bot`), `telegram/fake` (записывает отправленные сообщения, сбои `FailNext`; в dev пишет код в лог).
- Апдейты: webhook (`/telegram/webhook`) и long polling (`cmd/bot`) мапят входящее в `Update` и зовут один и тот же `domain/telegram.HandleUpdate`. Обработка идемпотентна по `UpdateID`.
- Тексты бота — в `backend/internal/domain/telegram/messages_ru.go` (бот только на русском в v1).

---

## 6. Схема БД (goose, `backend/internal/db/migrations/00001_init.sql`)

```sql
-- +goose Up
create extension if not exists citext;

create type platform        as enum ('android', 'windows');
create type server_group    as enum ('regular', 'whitelist');
create type server_protocol as enum ('vless_reality', 'hysteria2');
create type account_status  as enum ('provisioning', 'trial', 'active', 'expired', 'blocked');

create table accounts (
    id           uuid primary key default gen_random_uuid(),
    status       account_status not null default 'provisioning',
    expires_at   timestamptz,
    device_limit int not null default 5,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

create table telegram_users (
    telegram_id    bigint primary key,
    account_id     uuid not null unique references accounts(id) on delete cascade,
    chat_id        bigint not null,
    username       citext unique,          -- последний известный ник без @; null, если ника нет
    first_name     text not null default '',
    bot_blocked_at timestamptz,
    last_update_id bigint not null default 0,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

create table login_codes (
    id          uuid primary key default gen_random_uuid(),
    telegram_id bigint not null references telegram_users(telegram_id) on delete cascade,
    install_id  uuid not null,
    code_hash   bytea not null,            -- HMAC-SHA256(code, TOKEN_PEPPER)
    attempts    int not null default 0,
    expires_at  timestamptz not null,
    sent_at     timestamptz,
    consumed_at timestamptz,
    invalidated_at timestamptz,
    created_at  timestamptz not null default now()
);
create index login_codes_tg_created_idx on login_codes (telegram_id, created_at desc);

create table devices (
    id           uuid primary key default gen_random_uuid(),
    account_id   uuid not null references accounts(id) on delete cascade,
    install_id   uuid not null unique,
    platform     platform not null,
    model        text not null default '',
    app_version  text not null,
    token_hash   bytea not null unique,
    created_at   timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    revoked_at   timestamptz
);
create index devices_account_active_idx on devices (account_id) where revoked_at is null;

create table panel_users (
    account_id          uuid primary key references accounts(id) on delete cascade,
    remnawave_uuid      uuid not null unique,
    short_uuid          text not null unique,
    vless_uuid          text not null,   -- секрет, не логировать
    hysteria2_auth      text not null,   -- секрет, не логировать
    traffic_limit_bytes bigint not null default 0,
    traffic_used_bytes  bigint not null default 0,
    synced_at           timestamptz not null default now()
);

create table servers (
    id                  uuid primary key default gen_random_uuid(),
    remnawave_host_uuid uuid not null unique,
    grp                 server_group not null,
    protocol            server_protocol not null,
    display_name        text not null,
    country_code        char(2) not null,
    city                text,
    address             text not null,
    port                int not null check (port between 1 and 65535),
    params              jsonb not null default '{}'::jsonb,  -- несекретные параметры протокола
    enabled             boolean not null default true,
    sort_weight         int not null default 0,
    content_hash        text not null,                       -- sha256 нормализованных полей
    updated_at          timestamptz not null default now()
);
create index servers_grp_enabled_idx on servers (grp, sort_weight) where enabled;

-- +goose Down
drop table servers;
drop table panel_users;
drop table devices;
drop table login_codes;
drop table telegram_users;
drop table accounts;
drop type account_status;
drop type server_protocol;
drop type server_group;
drop type platform;
```

Правило ника: апдейт от пользователя с ником `X` в одной транзакции обнуляет `username = X` у другого `telegram_id` и записывает `X` текущему.

Таблицы River создаются `rivermigrate` в шаге `cmd/migrate` после goose. Биллинг, если решится, добавит таблицы новой миграцией и бампом ядра.

`infra/catalog/servers.yaml` — метаданные, которых нет в панели:

```yaml
- remnawaveHostUuid: 00000000-0000-0000-0000-000000000000
  group: regular            # regular | whitelist
  displayName: Frankfurt
  countryCode: DE
  city: Frankfurt
  sortWeight: 10
  enabled: true
```

---

## 7. Очередь: River

Реестр kind'ов и типов args — `backend/internal/jobs/kinds.go` (тимлид). Хендлеры живут в доменах слайсов.

| Kind | Args | Запуск | Эффект | Идемпотентность | Ретраи |
|---|---|---|---|---|---|
| `panel_provision_user` | `{accountId}` | первый `/start` в боте | создать пользователя в панели, записать `panel_users`, `accounts.status = trial`, `expires_at = now + TRIAL_DAYS` | unique by args; есть строка `panel_users` → no-op; `ErrConflict` → `GetUserByUsername` и принять существующего; insert `on conflict do nothing` | 10, экспонента; `ErrUnavailable` ретраится, остальное → `JobCancel` |
| `telegram_send_code` | `{loginId, code}` | `auth/telegram/start` | сообщение с кодом пользователю бота | `sent_at` не null или код инвалидирован/истёк → no-op; после отправки `sent_at = now()` | 3 с интервалом 2 с; `ErrBotBlocked` → `bot_blocked_at = now()`, `JobCancel` |
| `panel_sync_user` | `{accountId, reason}` | смена статуса, срока, лимита | отправить абсолютные значения срока и лимита в панель | `UpdateUser` с абсолютными значениями | 10 |
| `catalog_sync` | `{}` | periodic 5 мин + при старте worker | `ListHosts` + `servers.yaml` → upsert `servers` по `remnawave_host_uuid`, отсутствующие → `enabled = false` | upsert только при изменении `content_hash`; повтор не меняет `updated_at` | 3; periodic перекрывает |
| `account_expire` | `{}` | periodic 1 ч | `trial/active` с `expires_at < now()` → `expired`, на каждый — `panel_sync_user` | условие в `where` + unique by args у дочерних джобов | 3 |
| `demo_echo` | `{message}` | только скелет | лог | — | 1 |

Код в args `telegram_send_code` хранится в открытом виде только в строке джоба; после выполнения джоб удаляется ретеншеном River через 1 час. В логах args этого kind'а маскируются.

Общие правила:
- Хендлер обязан выдерживать повторный запуск с тем же payload с ровно одним эффектом. Тест обязателен (§10).
- Вставка джоба вместе с бизнес-записью — в одной транзакции (`InsertTx`).
- Таймаут джоба 30 с. Внешние вызовы с контекстом.

---

## 8. UI: токены и примитивы (`app/lib/ui`)

База: Material 3 Flutter, без сторонних UI-китов. Всё визуальное — через токены, примитивы не содержат захардкоженных цветов и размеров. Примитивы работают на тач и мыши (hover, фокус с клавиатуры).

Токены (`tokens.dart`, `theme.dart`):
- `AppColors` (light, dark): `bg`, `surface`, `surfaceAlt`, `primary`, `onPrimary`, `text`, `textMuted`, `success`, `warning`, `danger`, `connected`, `connecting`, `idle`, `border`.
- `AppSpacing`: 4, 8, 12, 16, 24, 32, 48.
- `AppRadius`: sm 8, md 12, lg 20, pill 999.
- `AppText`: display, title, body, label, caption.
- `AppDurations`: fast 150 ms, normal 250 ms, slow 400 ms.
- `AppLayout`: `maxContentWidth = 480`.
- `AppTheme.light()`, `AppTheme.dark()`; режим `system | light | dark` из `ui.theme`.

Примитивы:

| Компонент | Пропсы (эскиз) |
|---|---|
| `AppShell` | `child`; на Windows центрирует контент по `maxContentWidth` |
| `PowerButton` | `state: PowerState (idle, connecting, connected, disconnecting, error)`, `onPressed: VoidCallback?`, `size: double = 168`, `caption: String?` |
| `ModePager` | `pages: List<ModePage>`, `index: int`, `onChanged: ValueChanged<int>`; `ModePage { title, child }`; drag мышью и клавиши ← → |
| `PageDots` | `count: int`, `index: int`, `onTap: ValueChanged<int>?` |
| `ServerSheet` | `header: Widget`, `body: Widget`, `minExtent: double = 0.22`, `maxExtent: double = 0.9` |
| `ServerTile` | `title`, `subtitle?`, `countryCode?`, `ping: PingValue`, `selected: bool`, `onTap?`, `trailing?` |
| `PingBadge` | `value: PingValue (unknown, measuring, ms(int), unreachable)` |
| `FlagIcon` | `countryCode: String`, `size: double = 20` |
| `StatusBanner` | `kind: BannerKind (info, warning, error, success)`, `text`, `actionLabel?`, `onAction?` |
| `TrafficCounter` | `upBps`, `downBps` |
| `CodeInput` | `length: int = 6`, `onCompleted: ValueChanged<String>`, `errorText?`, `enabled: bool`; вставка кода из буфера |
| `SettingsSection` | `title`, `children`, `footer?` |
| `SettingsToggleTile` | `title`, `subtitle?`, `value: bool`, `onChanged?`, `locked: bool = false` |
| `SettingsSelectTile<T>` | `title`, `value: T`, `options: List<SelectOption<T>>`, `onChanged?`, `locked` |
| `SettingsNavTile` | `title`, `value?`, `onTap` |
| `SettingsInputTile` | `title`, `value`, `validator?`, `keyboardType?`, `onSubmitted?`, `locked` |
| `AppButton` | `label`, `onPressed?`, `variant: primary/secondary/text/danger`, `loading: bool`, `icon?` |
| `AppTextField` | `controller`, `label?`, `hint?`, `errorText?`, `keyboardType?`, `prefixText?` |
| `AppDialog.confirm` | `title`, `message`, `confirmLabel`, `danger: bool` → `Future<bool>` |
| `AppSnack.show` | `context`, `text`, `kind: BannerKind` |
| `EmptyState` | `icon`, `title`, `message?`, `action?` |
| `LoadingView` / `ErrorView` | `ErrorView { error, onRetry? }` |

`locked == true` → контрол недоступен, показывается иконка замка и подпись «Задано провайдером».

Kitchen-sink роут `/dev/kitchen-sink` (только debug-сборки) рендерит каждый примитив во всех состояниях в light и dark. Golden-тесты на каждый примитив.

Навигация — данные: `app/lib/app/routes.dart` содержит список роутов (`/login`, `/`, `/settings`, `/settings/*`, `/dev/kitchen-sink`) и гард: нет токена → `/login`. Слайс добавляет роут через issue `contract-change`, не правит роутер сам.

---

## 9. Инфраструктура и владение

- **Миграции**: только тимлид. goose SQL в `backend/internal/db/migrations`. sqlc читает схему из миграций. Применяются в деплой-шаге (`cmd/migrate`: goose up → rivermigrate up). В PR-гейте прогоняются на эфемерном Postgres. Слайсы миграции не пишут.
- **Сид**: `cmd/seed` + `contracts/fixtures/seed/*.json`. Один набор данных на всё: локальная БД, fake PanelClient, fake TelegramClient, Dart-фикстуры профиля, Go- и Dart-тесты. Состав: 3 regular-сервера (2 VLESS Reality, 1 Hysteria2 с port hopping), 2 whitelist-сервера, 1 аккаунт `trial` с Telegram-пользователем `seed_user`, 1 устройство с известным dev-токеном.
- **Фейки внешних систем**: `panel/fake`, `telegram/fake` (бэкенд); `FakeVpnBridge` (app: проигрывает сценарии CoreEvent), `FakeApiClient` (app, офлайн-режим из фикстур).
- **Конфиг бэкенда**: `backend/internal/config` читает env в типизированную структуру, валидирует на старте. `.env.example`:

```
APP_ENV=dev                     # dev | staging | prod
HTTP_ADDR=:8080
METRICS_ADDR=:9090
LOG_LEVEL=info
DATABASE_URL=postgres://vpn:vpn@localhost:5432/vpn?sslmode=disable
PANEL_MODE=fake                 # fake | remnawave
REMNAWAVE_BASE_URL=
REMNAWAVE_API_TOKEN=
TELEGRAM_MODE=fake              # fake | polling | webhook
TELEGRAM_BOT_TOKEN=
TELEGRAM_BOT_USERNAME=
TELEGRAM_WEBHOOK_SECRET=
CATALOG_FILE=../infra/catalog/servers.yaml
TOKEN_PEPPER=change-me-32-bytes-min
TRIAL_DAYS=3
AUTH_RATE_PER_MIN=10
```

- **Конфиг app**: `--dart-define-from-file=env/<flavor>.json`: `FLAVOR`, `API_BASE_URLS` (через запятую), `FAKE_VPN` (bool), `FAKE_API` (bool). Флейворы `dev`, `staging`, `prod`. Windows-сборка staging ставится рядом с prod под другим именем службы и pipe.
- **Разработка без секретов**: `make dev` поднимает Postgres в Docker, бэкенд с `PANEL_MODE=fake` и `TELEGRAM_MODE=fake`, сид. Код входа печатается в лог. App запускается с `FAKE_VPN=true` на Windows-десктопе без службы.
- **Make-цели**: `make gen` (все генераторы), `make check` (format, lint, analyze, vet, gen без диффа), `make test`, `make seed`, `make dev`, `make core-android` (`.aar`), `make core-windows` (`vpnsvc.exe`), `make installer` (только на Windows).
- **Приватность**: бэкенд не хранит IP клиентов и логи соединений. Access-лог Caddy без IP. Access-логи Xray на нодах выключены. Секреты (`vless_uuid`, `hysteria2_auth`, токены устройств, коды входа, токен бота) никогда не попадают в логи и метрики.

---

## 10. Стратегия тестов

Тесты привязаны к слайсу и PR. Слайс мёрджится только с тестами, гейт красный без них.

**Главное правило: тесты выводятся из критериев приёмки задачи, не из реализации.** Сначала из карточки слайса пишутся тесты по каждому критерию, потом код. Тест кодирует контракт, не зеркалит код. Тест, который подтверждает, что код делает то, что делает, вместе с багами, не принимается.

Обязательные типы тестов на слайс:

1. **Контрактные на стыках.** Самые ценные.
   - Бэкенд: каждый ответ handler'а валидируется против `contracts/openapi.yaml` (kin-openapi).
   - Общие фикстуры `contracts/fixtures/{profile,tunnel_request,core_event}/*.json` проверяются с обеих сторон: Go парсит и валидирует, Dart парсит generated-моделями и сериализует обратно без потерь.
   - IPC: записанные сессии `contracts/fixtures/ipc/*.jsonl` (запрос → ответ → нотификации) проигрываются против `core/internal/ipc` и против `PipeVpnBridge` с in-memory транспортом.
   - Ядро: `TunnelRequest` от app валидируется схемой; каждый `CoreEvent` ядра проходит схему.
   - Фейк — тестовый шов: `panel/fake`, `telegram/fake`, `FakeVpnBridge` валидируют вход против контракта и падают на мусоре.
2. **Идемпотентность джобов River и апдейтов бота.** На каждый хендлер — тест: дважды с тем же payload, эффект ровно один (одна строка, один `CreateUser`, одно сообщение, неизменный `updated_at`). Повтор апдейта Telegram с тем же `UpdateID` — без эффекта.
3. **Путь ошибки.** Через фейки: панель вернула 5xx, таймаут, `ErrConflict`; бот заблокирован пользователем; Telegram 429; неверный и истёкший код; ядро вернуло `start_failed`; служба Windows недоступна; API недоступен → fallback-эндпоинт; профиль из кэша.
4. **Property-based на чистой логике.** Go — `rapid`: `config.BuildOptions` (C1–C6), `autoswitch.Next` (I1–I6), нормализация каталога, нормализация ника. Dart — `glados`: `sortServers`, слияние `ClientPolicy` с пользовательскими настройками, выбор сервера для автоподключения.
5. **UI.** Widget-тесты на переходы состояний экранов с фейками; golden-тесты на примитивы.

Нативные части: JUnit на маппинг типа сети и проброс событий без изменения JSON; Go-тесты `vpnsvc` (pipe-транспорт, ACL, определение типа сети) на windows-раннере. Ручной чек туннеля на реальном устройстве или машине — пункт в описании PR для слайсов `android`/`windows`.

Если сессия в Claude Code и установлен skill `engineering:testing-strategy` — использовать его для плана тестов слайса.

---

## 11. Правила кода

Общее:
- Контракты не выдумываются. Нет типа, поля, эндпоинта, kind'а, ключа настройки → `CONTRACT GAP`.
- Generated-код не правится руками. Изменение контракта → `make gen` → коммит generated.
- Одна задача за раз, сфокусированный дифф. Не трогать чужие домены и контрактные пути.
- Строки для пользователя в app — только через l10n (ru, en). Хардкод запрещён. Тексты бота — в `messages_ru.go`.
- Секреты не коммитятся. Новый env → issue `contract-change` на `.env.example` и `config`.

Go:
- `gofmt`, `golangci-lint` (конфиг в репо). Ошибки оборачиваются `fmt.Errorf("...: %w", err)`; доменные sentinel-ошибки в пакете домена; паника в handler'ах, джобах и службе запрещена.
- `context.Context` первым аргументом во всём, что ходит в сеть или БД.
- Логи — `log/slog`, структурные ключи, без секретов. `vpnsvc` пишет в `%ProgramData%\<app>\logs` с ротацией.
- Доступ к БД только через sqlc-запросы домена. Транзакции — `pgx.Tx` в сервисе.
- Handler тонкий: парсинг → сервис → маппинг ответа.

Dart / Flutter:
- `flutter_lints` + `strict-casts`, `strict-inference`, `strict-raw-types`. `dynamic` запрещён.
- Слои фичи: `domain` (чистые модели и функции, без Flutter), `data` (репозитории, API), `application` (Riverpod-провайдеры и контроллеры), `presentation` (экраны и локальные виджеты).
- Состояния — sealed-классы. Логики в виджетах нет.
- Фичи зависят от `VpnBridge`, не от Pigeon или pipe напрямую. Платформенные ветки (`Platform.isWindows`) только в `app/lib/core`.
- Экраны собираются из примитивов `lib/ui`. Самописный UI в фиче допустим только как локальная композиция примитивов.

Kotlin:
- Хост тонкий: жизненный цикл, разрешения, уведомления, тип сети, проброс в core. Бизнес-логики нет. ktlint.

---

## 12. Коммиты, PR, комментарии

Применяют все сессии.

- Язык — только английский: коммиты, заголовки и описания PR, комментарии в коде.
- Формат коммита фиксированный, всегда: `type(scope): summary`.
  - `type` ∈ `feat | fix | test | refactor | chore | docs`.
  - `scope` ∈ `app | android | windows | core | backend | bot | contracts | infra | ci`.
  - `summary`: императив, со строчной, без точки, до ~50 символов.
  - Тело только чтобы объяснить почему, не что.
- Сессия коммитит сама по ходу работы: маленький логический коммит после каждого осмысленного шага. Каждый коммит по возможности проходит тайпчек и анализатор.
- Ветка: `<linear-id>-<slice-id>-<short-name>`, например `vpn-42-s1-08-power-button`.
- PR: заголовок краткий, в формате коммита, с ID issue Linear: `feat(app): connect flow on power button (VPN-42)`. Тело:
  - `Slice:` ID и название;
  - `Core: tech.md vN`;
  - что делает слайс;
  - какие контракты и типы затрагивает (только использует — контракты меняет тимлид);
  - чем покрыт тестами (по критериям приёмки);
  - для android/windows — результат ручного чека.
- Комментарии в коде кратко объясняют почему, не пересказывают код. Закомментированный код в PR не оставлять.
- Дисциплина `stop-slop` на всю прозу: активный залог, императив, конкретика, без em-dash, без филлеров.

---

## 13. CONTRACT GAP

Не хватает контракта, типа, поля, эндпоинта, kind'а, ключа настройки, роута, примитива, метода IPC → **СТОП**. Код с выдуманным типом не пишется. Сессия выдаёт блок:

```
CONTRACT GAP
Slice: S1-09
Need: <что нужно: поле / тип / эндпоинт / kind / примитив / метод IPC>
Why: <какой критерий приёмки без этого не выполнить>
Proposed shape: <точная форма: схема, сигнатура, пропсы>
Affects: <пути и стороны: backend / bot / core / app / android / windows>
Workaround until merged: <локальная заглушка в пределах слайса>
```

Дальше:
1. Открыть issue Linear с меткой `contract-change`, вставить блок.
2. Продолжать на локальной заглушке внутри своих путей. Заглушка помечена `// TODO(CONTRACT GAP <issue-id>)` и не уходит в main.
3. Тимлид аппендит контракт в `tech.md`, бампает версию, правит `contracts/`, запускает `make gen`, мёрджит, закрывает issue.
4. Сессия ребейзится на main и заменяет заглушку.

Тулинговая защита: workflow `contract-guard` валит PR, который трогает контрактные пути (§5.1) без метки `contract-change` или без бампа версии в `tech.md`.

---

## 14. Definition of Done (одна задача)

- [ ] Все критерии приёмки карточки выполнены.
- [ ] Тесты выведены из критериев приёмки; есть контрактный тест на стыке слайса; для каждого джоба и обработчика апдейтов — тест идемпотентности; путь ошибки покрыт через фейк; чистая логика — property-based.
- [ ] `make check` и `make test` зелёные локально; CI зелёный.
- [ ] `make gen` не даёт диффа.
- [ ] Build проходит: бэкенд, `flutter build apk --debug`, `flutter build windows`, `vpnsvc.exe`.
- [ ] Не тронуты чужие домены и контрактные пути.
- [ ] Новые пользовательские строки в ru и en.
- [ ] PR привязан к issue Linear, оформлен по §12.
- [ ] Для android/windows — ручной чек описан в PR.

---

## 15. Скелет

### 15.1 Порядок сборки (тимлид, слайсы S0-xx)

Фичи не начинаются, пока весь чек-лист 15.3 не зелёный.

| ID | Что | Готово когда |
|---|---|---|
| S0-01 | Монорепо, `.tool-versions`, Makefile, линтеры, `contract-guard`, workflow `pr.yml` (ubuntu + windows-раннер) | тривиальный PR проходит CI |
| S0-02 | Контракты v1: `openapi.yaml`, `vpn_api.dart`, IPC-протокол, фикстуры; генерация Go (backend, core) и Dart | `make gen` чистый, фикстуры валидны с обеих сторон |
| S0-03 | Бэкенд-каркас: config, chi, `/healthz`, `/metrics`, problem+json, auth middleware, миграция 00001, sqlc, River client + worker + `demo_echo`, `panel/fake`, `telegram/fake` | `go test ./...` зелёный, миграции на эфемерном Postgres |
| S0-04 | Core-каркас: модуль, `runtime`, `bind.Core`, старт box на фикстурном direct-конфиге, события JSON, `make core-android` | `.aar` собирается в CI |
| S0-05 | App-каркас: Riverpod, go_router, роуты-данные с гардом входа, l10n ru/en, токены, тема light/dark, все примитивы §8, kitchen-sink, `ModePager` с двумя пустыми экранами, `VpnBridge` + `FakeVpnBridge`, storage, generated API-клиент; запуск на Android и Windows | kitchen-sink рендерится на обеих платформах, goldens закоммичены |
| S0-06 | Android-хост: `TunnelService`, `PigeonVpnBridge`, подключение `.aar`, старт и стоп фикстурного туннеля | события ядра доходят до Dart на эмуляторе |
| S0-07 | Windows-хост: `vpnsvc` (служба, pipe, `hello`/`start`/`stop`/`getState`/`subscribe`), `PipeVpnBridge`, черновой Inno Setup | установщик ставит службу; события доходят до Dart на Windows-машине |
| S0-08 | Эталонная вертикаль (15.2) | в main и на staging |
| S0-09 | Staging: Ansible-роль `api-host`, Compose (api, worker, postgres, caddy), `deploy-staging.yml` на мёрдж в main, Prometheus + Grafana базово | `curl https://<staging>/healthz` 200 после мёржа |
| S0-10 | Сид: `cmd/seed`, `contracts/fixtures/seed`, общий для fake panel, fake telegram, БД и Dart | `make seed` наполняет БД; фейки отдают те же данные |

### 15.2 Эталонная вертикаль: «профиль → список серверов»

Шаблон для всех слайсов. Новый слайс повторяет эту раскладку файлов и тестов. Вход в эталоне не участвует: используется сид-устройство с dev-токеном.

Бэкенд:
- `backend/internal/domain/profile/` — `service.go` (Build: аккаунт + серверы + policy + ETag), `handler.go`, `store.go`, `service_test.go` (property: ETag стабилен при неизменных данных и меняется при изменении любого сервера), `handler_contract_test.go`.
- `backend/internal/db/queries/profile.sql`.

App:
- `app/lib/features/profile/domain/` — модели-обёртки, `ProfileState` (sealed).
- `app/lib/features/profile/data/profile_repository.dart` — API + кэш на диске + ETag.
- `app/lib/features/profile/application/profile_controller.dart` — Riverpod.
- `app/lib/features/profile/presentation/server_list.dart` — `ServerSheet` + `ServerTile` на экране `regular`, только чтение.
- Тесты: `test/features/profile/` — репозиторий против `FakeApiClient` и фикстур, контроллер, widget-тест списка, путь ошибки (API 5xx → кэш), 401 → переход на `/login`.

### 15.3 Чек-лист «скелет готов»

- [ ] CI зелёный на тривиальном PR, все джобы `pr.yml` на ubuntu и windows.
- [ ] `contract-guard` валит PR, трогающий `contracts/` без метки.
- [ ] Контракты v1 в main, `make gen` без диффа.
- [ ] Миграции проходят на эфемерном Postgres в CI.
- [ ] River-worker выполняет `demo_echo`.
- [ ] `panel/fake` и `telegram/fake` отдают сид-данные; `make seed` наполняет БД.
- [ ] Shell app, роуты-данные с гардом, `ModePager` с двумя экранами в main, работают на Android и Windows.
- [ ] Все UI-примитивы отрендерены в `/dev/kitchen-sink` в light и dark, goldens закоммичены.
- [ ] Транспорт событий: `CoreEvent` доходит до Dart на Android-эмуляторе, на Windows через `vpnsvc` и через `FakeVpnBridge`.
- [ ] `.aar`, `vpnsvc.exe` и установщик собираются в CI.
- [ ] Эталонная вертикаль в main и задеплоена на staging; профиль с сид-устройством отдаёт сид-серверы.

---

## 16. Дорожная карта: стадии и слайсы

Каждая карточка = один PR. Формат: пути, контракты, UI, приёмка, тесты. Порядок внутри стадии — сверху вниз, если не указано иное.

### Стадия 1 — Вход и обычный VPN (MVP)

#### S1-01 · core: ConfigBuilder v1
- Пути: `core/internal/config/`.
- Контракты: TunnelRequest v1, §5.8.
- Приёмка: VLESS Reality Vision и Hysteria2 (с port hopping и salamander) собираются в валидные опции для Android и Windows; группы и селекторы по §5.8; `selected` на отсутствующий сервер → первый по `sortWeight`; пустая группа не создаётся.
- Тесты: rapid C1–C6; фикстуры `contracts/fixtures/tunnel_request/*` → опции проходят `box.New`; невалидный запрос → `config_invalid`.

#### S1-02 · core: жизненный цикл и события
- Пути: `core/internal/runtime/`, реализация `core/bind/` (сигнатуры заморожены).
- Контракты: §5.5, §5.9.
- Приёмка: `Start` → `connecting` → `connected`; `Stop` → `disconnecting` → `disconnected`; `Update` пересобирает и перезапускает; `SelectServer` и `SetUserMode` без рестарта; `traffic` раз в секунду в `connected`.
- Тесты: каждый эмитированный JSON проходит схему CoreEvent; ошибка старта → `error` с `start_failed`; двойной `Start` не создаёт второй box.

#### S1-03 · android: TunnelService
- Пути: `app/android/.../tunnel/`.
- Контракты: VpnApi v1.
- Приёмка: foreground-уведомление со статусом и кнопкой «Отключить»; поддержка системного always-on; отзыв VPN другим приложением → `revoked`; свой пакет исключён из туннеля.
- Тесты: JUnit на маппинг событий; ручной чек на устройстве.

#### S1-04 · windows: служба vpnsvc и установщик
- Пути: `core/cmd/vpnsvc/`, `core/internal/ipc/` (кроме `protocol.go`), `installer/windows/` через тимлида.
- Контракты: IPC vpnsvc v1 (§5.6).
- Приёмка: все методы IPC; служба `Automatic`, перезапуск при падении; ACL pipe по §5.6; `last_request.json` сохраняется при `start`; установщик ставит и обновляет службу без перезагрузки, удаление снимает службу и адаптер; две копии UI получают одни и те же события.
- Тесты: сессии `contracts/fixtures/ipc/*.jsonl` против in-memory транспорта; `ipc_version_mismatch`; неизвестный метод → JSON-RPC `-32601`; Go-тест ACL на windows-раннере; ручной чек на чистой Windows 11.

#### S1-05 · bot: Telegram-бот и выдача аккаунтов
- Пути: `backend/internal/telegram/botapi/`, `backend/internal/domain/telegram/`, `backend/cmd/bot/`.
- Контракты: §2.2, §5.10 TelegramClient, таблица `telegram_users`, джоб `panel_provision_user` (постановка).
- Приёмка: `/start` создаёт аккаунт и `telegram_users`, ставит `panel_provision_user` в той же транзакции, отвечает инструкцией «введите ваш ник в приложении»; повторный `/start` не создаёт второй аккаунт; без ника — просьба задать ник; смена ника обновляет `username` по правилу §6; блокировка бота → `bot_blocked_at`; webhook проверяет секрет.
- Тесты: идемпотентность по `UpdateID`; дубль `/start` → один аккаунт и один джоб; конфликт ника между двумя пользователями; webhook без секрета → 401; тексты сообщений против fake.

#### S1-06 · backend: вход по коду из бота
- Пути: `backend/internal/domain/auth/`.
- Контракты: `/v1/auth/telegram/*`, `/v1/auth/logout`, таблицы `login_codes`, `devices`, джоб `telegram_send_code`.
- Приёмка: всё из §5.2 для `start`, `verify`, `logout`: нормализация ника, `telegram_user_not_found` с `botUrl`, cooldown 60 с, 5 кодов в час, TTL 5 мин, 5 попыток, одноразовость, повторный `start` инвалидирует прежний код, лимит устройств, переиспользование `deviceId` по `installId`; код в сообщении бота с моделью устройства и предупреждением «если это не вы — проигнорируйте».
- Тесты: контрактные на все ответы; идемпотентность `telegram_send_code`; property на нормализацию ника; путь ошибки: бот заблокирован, Telegram 429; перебор кода упирается в `code_expired`; гонка двух `verify` с одним кодом даёт один успех.

#### S1-07 · app: экран входа
- Пути: `app/lib/features/auth/`.
- Контракты: `/v1/auth/telegram/*`, `AuthResult`.
- UI: `AppTextField` (префикс `@`), `CodeInput`, `AppButton`, `StatusBanner`, `EmptyState`.
- Приёмка: ввод ника → экран кода с таймером повторной отправки и кнопкой «Открыть бота»; `telegram_user_not_found` → экран «Откройте бота и нажмите Start» с кнопкой-ссылкой и «Я нажал Start, отправить код»; ввод кода → токен в secure storage → главный экран; ошибки по кодам с оставшимися попытками; выход из аккаунта в настройках.
- Тесты: widget-тесты каждого шага против `FakeApiClient`; путь ошибки: каждый код ошибки из §5.2 даёт свой текст; 401 на профиле → возврат на вход.

#### S1-08 · app: подключение на экранах режимов
- Пути: `app/lib/features/connection/`.
- Контракты: `VpnBridge`, TunnelRequest v1, CoreEvent v1.
- UI: `PowerButton`, `StatusBanner`, `TrafficCounter`.
- Приёмка: таблица состояний кнопки из §2.1; отказ в разрешении (Android) или `service_unavailable` (Windows) → баннер; ошибка ядра → `error` + баннер с текстом по коду; таймер подключения из `connectedSince`.
- Тесты: widget-тесты каждой строки таблицы §2.1 с `FakeVpnBridge`; тап на экране неактивного режима зовёт `setUserMode`, не `start`; `TunnelRequest` из контроллера проходит фикстурную схему; путь ошибки `start_failed`.

#### S1-09 · app: список серверов и выбор
- Пути: `app/lib/features/servers/`.
- UI: `ServerSheet`, `ServerTile`, `FlagIcon`, `EmptyState`.
- Приёмка: на каждом экране режима серверы своей группы; выбор сохраняется для группы; при connected выбор в активной группе → `selectServer` без переподключения; пустой список → `EmptyState`.
- Тесты: контроллер против фикстур профиля; выбор при connected зовёт `selectServer`, не `start`.

#### S1-10 · backend: Remnawave PanelClient + провижининг
- Пути: `backend/internal/panel/remnawave/`, `backend/internal/domain/account/`.
- Контракты: §5.10 PanelClient, джоб `panel_provision_user`.
- Приёмка: джоб создаёт или принимает пользователя панели; профиль после провижининга отдаёт серверы с кредами пользователя; ADR про поля Reality и Hysteria2 в API панели.
- Тесты: идемпотентность (дважды → один `CreateUser`, одна строка); `ErrConflict` → принятие существующего; `ErrUnavailable` → ретрай; контрактный тест generated-клиента на записанных ответах панели.

#### S1-11 · backend: синхронизация каталога
- Пути: `backend/internal/domain/catalog/`.
- Контракты: джоб `catalog_sync`, `servers.yaml`.
- Приёмка: хосты панели + yaml → `servers`; хост без записи в yaml не публикуется; исчезнувший хост → `enabled = false`.
- Тесты: идемпотентность (повтор не меняет `updated_at`); rapid на нормализацию и `content_hash`; панель недоступна → каталог не трогается.

#### S1-12 · app: пинг и сортировка по пингу
- Пути: `app/lib/features/ping/`.
- Контракты: `ping.*`, `ui.sortByPing`.
- UI: `PingBadge`, `SettingsToggleTile` (тумблер в шапке `ServerSheet`).
- Приёмка: TCP-пинг всех видимых серверов, параллельно не больше 8; пинг при открытии по `ping.onOpen`; тумблер сортировки; `url_test` через ядро в connected.
- Тесты: glados на `sortServers` (перестановка входа; недоступные в конце; стабильность при равных; выключено → порядок `sortWeight`); таймаут → `unreachable`.

#### S1-13 · infra: Remnawave staging
- Пути: `infra/ansible/roles/remnawave-*`, `infra/compose/remnawave/`.
- Приёмка: панель и 2 ноды разворачиваются плейбуком; inbound'ы VLESS Reality Vision TCP 443 и Hysteria2 UDP с port hopping; node_exporter; access-логи Xray выключены; webhook бота за Caddy.
- Тесты: `ansible-lint`; smoke-скрипт: sing-box с фикстурным конфигом проходит `url_test` через каждую ноду.

### Стадия 2 — Белые списки

#### S2-01 · app: экран «Белые списки»
- Пути: `app/lib/features/whitelist/`.
- UI: `ModePager`, `PageDots`, `PowerButton`, `ServerSheet`.
- Приёмка: второй экран со whitelist-серверами; свайп, клик по `PageDots` и клавиши ← → только переключают экран; нет whitelist-серверов → `EmptyState`.
- Тесты: widget-тест: свайп не зовёт ни один метод `VpnBridge`.

#### S2-02 · core: автопереключение
- Пути: `core/internal/autoswitch/`, интеграция в runtime.
- Контракты: §5.7, CoreEvent `mode`.
- Приёмка: правила и переходы §5.7; смена группы через селектор `proxy`.
- Тесты: rapid I1–I6; табличный тест сценариев из §5.7.

#### S2-03 · android: мониторинг сети
- Пути: `app/android/.../tunnel/NetworkMonitor.kt`.
- Приёмка: Wi-Fi, cellular, ethernet, none мапятся в `NetType`; debounce 1 с; работает при свёрнутом и убитом UI.
- Тесты: JUnit на маппинг и debounce; ручной чек: выключить Wi-Fi при подключённом туннеле.

#### S2-04 · windows: мониторинг сети
- Пути: `core/cmd/vpnsvc/netmon_windows.go`.
- Приёмка: определение `NetType` по §5.7 (WWAN или лимитная сеть → cellular); адаптер wintun игнорируется; debounce 1 с.
- Тесты: табличный тест маппинга (тип интерфейса, стоимость) → `NetType`; ручной чек: раздача с Android-телефона, помеченная лимитной.

#### S2-05 · app: тумблер автоперехода и синхронизация UI
- Пути: `app/lib/features/whitelist/`, `app/lib/features/connection/`.
- Контракты: `whitelist.autoOnCellular`, `policy.flags.autoWhitelist`.
- UI: `SettingsToggleTile`, `StatusBanner`.
- Приёмка: тумблер на экране «Белые списки» и в настройках; событие `mode` с причиной `network_*` показывает баннер и анимирует пейджер на `effectiveMode`; `no_whitelist_servers` → баннер-предупреждение; флаг выключен → тумблер скрыт.
- Тесты: widget-тесты на каждую причину из `ModeSwitchReason` с `FakeVpnBridge`.

#### S2-06 · app: устойчивость без доступа к API
- Пути: `app/lib/features/profile/data/` (расширение эталона по issue), `app/lib/core/` через тимлида.
- Контракты: `endpoints.api`, `policy.ruleSets`.
- Приёмка: профиль из кэша при недоступном API; перебор `endpoints.api` по порядку с таймаутом 9 с; rule sets из ассетов приложения как fallback; подключение возможно офлайн с кэшированным профилем.
- Тесты: путь ошибки: основной эндпоинт 5xx → fallback; все недоступны → кэш; нет кэша → `ErrorView`.

#### S2-07 · infra: whitelist-ноды и пробы
- Пути: `infra/ansible/`, `infra/monitoring/`.
- Приёмка: whitelist-ноды на хостинге из белых списков операторов; Reality SNI на домене из белого списка; blackbox-пробы из российской точки присутствия; алерт на падение пробы.
- Тесты: `ansible-lint`; ручная проверка с SIM-картами операторов по чек-листу в PR.

### Стадия 3 — Настройки (база из Happ)

#### S3-01 · app: экран настроек и интерфейс
- Пути: `app/lib/features/settings/`.
- UI: `SettingsSection`, `SettingsSelectTile`, `SettingsNavTile`.
- Приёмка: разделы: Аккаунт, Подключение, Маршрутизация, Приложения, Сеть, DNS, Пинг, Интерфейс; язык ru/en/системный и тема светлая/тёмная/системная применяются без перезапуска.
- Тесты: glados на слияние `ClientPolicy.defaults` + пользовательские значения + `locked`; widget-тест смены темы и языка.

#### S3-02 · маршрутизация
- Пути: `app/lib/features/routing/`; правила пресетов в `core/internal/config/presets.go`.
- Приёмка: вкл/выкл; пресеты `ru_direct` и `all_proxy`; свои правила domain / domain_suffix / domain_keyword / ip_cidr → proxy / direct / block, порядок перетаскиванием; rule sets из `policy.ruleSets` с проверкой `sha256` (Android — app, Windows — служба через `syncRuleSets`).
- Тесты: валидация значений правил (property: валидный CIDR принимается, мусор нет); неверный `sha256` → файл не используется; фикстуры с правилами проходят C1.

#### S3-03 · раздельное туннелирование приложений
- Пути: `app/lib/features/split_apps/`.
- Контракты: `perApp`, `VpnHostApi.listApps`, IPC `listProcesses`.
- Приёмка: режимы off / include / exclude; Android — выбор из установленных пакетов с поиском, свой пакет нельзя включить в туннель; Windows — выбор из запущенных процессов и ручной ввод имени `.exe`.
- Тесты: контроллер; опции содержат `include_package` / `exclude_package` на Android и `process_name` на Windows (C5).

#### S3-04 · сеть и DNS
- Пути: `app/lib/features/network_settings/`.
- Приёмка: DNS remote/direct, стратегия, IPv6, sniffing, TLS fragment, MTU (1280..9000), TUN stack, exclude routes (CIDR), обход локальной сети; изменение при connected → `update`.
- Тесты: валидация MTU и CIDR (property); каждая комбинация из фикстур проходит C1; ADR о совместимости фрагментации с Reality.

#### S3-05 · поведение подключения и автозапуск
- Пути: `app/lib/features/connect_behavior/`.
- Приёмка: автоподключение при запуске (last_used / lowest_ping / random); `connect.autostart`: Android — `BOOT_COMPLETED` → хост поднимает туннель с последним запросом; Windows — запуск UI при входе в систему, служба подключает по `last_request.json`; тип пинга `tcp` / `url_test`, URL, таймаут.
- Тесты: glados на выбор сервера по стратегии (lowest_ping никогда не выбирает unreachable при наличии доступных); пустой список → нет автоподключения.

#### S3-06 · windows: трей и окно
- Пути: `app/lib/features/desktop_shell/` (обвязка через `app/lib/core` по issue).
- Приёмка: иконка в трее с состоянием и пунктами «Подключить / Отключить / Открыть / Выход»; закрытие окна сворачивает в трей; одна копия приложения; «Выход» закрывает UI, туннель остаётся под службой, пока пользователь не отключит.
- Тесты: контроллер меню трея против `FakeVpnBridge`; ручной чек.

#### S3-07 · удалённая политика и обновления
- Пути: `backend/internal/domain/profile/` (policy из `backend/config/policy.yaml` через issue), `app/lib/features/settings/`, `app/lib/features/app_update/`.
- Приёмка: `defaults` применяются; `locked` блокирует контролы с подписью; `minAppVersion` выше текущей → экран обновления; `appUpdate` → предложение обновиться, на Windows скачивание установщика с проверкой `sha256` и запуск.
- Тесты: контрактный тест профиля с политикой; glados на слияние; неверный `sha256` → установщик не запускается.

#### S3-08 · статус подписки и объявления
- Пути: `app/lib/features/account_status/`.
- UI: `StatusBanner`, `TrafficCounter`.
- Приёмка: трафик использовано/лимит, срок, ник Telegram; предупреждение за 3 дня и после истечения со ссылкой на бота; объявление из профиля с кнопкой.
- Тесты: widget-тесты по фикстурам статусов.

### Стадия 4 — Аккаунт и устройства

#### S4-01 · bot: управление устройствами
- Требует бампа ядра: kind'ов для callback'ов, если понадобятся.
- Приёмка: команда `/devices` — список устройств аккаунта (платформа, модель, последний вход) с кнопкой «Отключить»; отзыв ставит `revoked_at`, устройство получает `device_revoked`; команда `/status` — статус и срок.
- Тесты: идемпотентность callback'а отзыва; чужое устройство отозвать нельзя.

#### S4-02 · биллинг
- Заблокирован решением по оплате (§18). Интерфейс провайдера + fake появятся в ядре вместе с решением. Оплата и продление планируются через бота.

### Стадия 5 — Эксплуатация и релиз

#### S5-01 · мониторинг и алерты
- Дашборды: API (RPS, latency, 5xx), бот (апдейты, ошибки отправки), River (очереди, ошибки), ноды (CPU, сеть, онлайн), пробы. Алерты в Telegram.

#### S5-02 · прод
- Окружение prod, `deploy-prod.yml` на тег `v*` с ручным подтверждением environment; бэкапы Postgres (бэкенд и Remnawave) с проверкой восстановления.

#### S5-03 · релизы приложений
- Android: подпись, декларация VpnService в Play; APK для прямой загрузки с публикацией в `appUpdate`.
- Windows: подпись `vpnsvc.exe`, приложения и установщика; публикация установщика в `appUpdate`.

---

## 17. Long-lead (запустить в день один)

Long-lead блокирует реальную интеграцию, не разработку. Разработка идёт против фейков с первого дня.

| Что | Блокирует | Заметка |
|---|---|---|
| Сертификат подписи кода для Windows | S5-03, ручные проверки на чистых машинах | без подписи SmartScreen и антивирусы блокируют установщик и службу; репутация SmartScreen набирается со временем |
| Отправка сборок на анализ в Microsoft Defender | S5-03 | Go-бинарники VPN часто ловят ложные срабатывания |
| Google Play: декларация VpnService | S5-03 | ревью идёт отдельно |
| Хостинг с IP из белых списков операторов + SIM-карты МТС, Билайн, МегаФон, Т2 для проверки | S2-07 | без этого белые списки проверяются только на фейках |
| Домены: основной API, fallback-домены, домен webhook бота | S0-09, S2-06 | fallback-домены держать в инфраструктуре, доступной при белых списках |
| Бот в BotFather: имя, ник, токен, описание | S1-05 | ник бота попадает в `botUrl` и тексты приложения |
| Платёжный провайдер | S4-02 | решение открыто |

---

## 18. Открытые вопросы и принятые допущения

Каждое допущение меняется только бампом ядра.

1. Биллинг не определён: провайдер, тарифы, цена. Предполагается оплата через бота.
2. Клиентское ядро sing-box, не Xray. Не переносятся Mux, noises, XHTTP, No Limit Mode.
3. ICMP-пинг не поддерживается.
4. Пользователь без ника в Telegram не входит в v1; бот просит задать ник.
5. Вход требует доступа к Telegram. При мобильном интернете в режиме белых списков первый вход может не пройти; уже вошедшее устройство работает с кэшированным профилем.
6. Определение мобильной сети на Windows опирается на признак лимитной сети; раздача с телефона без этого признака распознаётся как Wi-Fi.
7. Название приложения, application id, `<app-id>` для службы и pipe — плейсхолдеры до решения.

---

## 19. Поправки ядра v2

Раздел имеет приоритет над §1–§18. Рабочий плейсхолдер имени до решения §18.7: `vpnclient`.

### 19.1 Стадия 0 без серверов

- S0-09 делится на две части. **S0-09a**: Compose, роль `api-host`, `deploy-staging.yml` и базовый мониторинг; готово, когда стек поднимается локально и `/healthz` отвечает 200. **S0-09b**: деплой на VPS и домен; готово, когда `curl https://<staging>/healthz` отвечает 200.
- S0-08 готов, когда вертикаль в main и проверена локально через `make dev`.
- Пункт §15.3 «задеплоена на staging» заменяется на «проверена локально». Стадия 1 стартует без S0-09b.
- S0-09b закрывается до S1-13.

### 19.2 Порядок слайсов

- Стадия 0: S0-01, S0-02, S0-03, S0-04, S0-05, S0-06, S0-07, S0-10, S0-09a, S0-08.
- Стадия 1: S1-13 выполняется до S1-10, потому что S1-10 нужны записанные ответы живой панели.
- S1-10, S1-13 и S2-07 ждут серверы. Ручная проверка реального туннеля в S1-03 и S1-04 ждёт S1-13.

### 19.3 Трекер задач

GitHub Issues заменяет Linear во всех правилах §12, §13 и §14.

- Ветка: `gh-<issue>-<slice-id>-<short-name>`, например `gh-42-s1-08-power-button`.
- Заголовок PR: `feat(app): connect flow on power button (#42)`.
- Метка `bootstrap` освобождает PR от бампа версии, пока не закрыта стадия 0. Вместе с закрытием стадии 0 метка и её обработка в `contract-guard` удаляются.

### 19.4 Сборка

- gomobile и gobind берутся из форка `github.com/sagernet/gomobile`, который использует upstream sing-box. Версия зафиксирована в `.tool-versions`.
- Dart входит в Flutter и отдельно не фиксируется. Inno Setup устанавливается только на windows-раннере и в `.tool-versions` не входит.
- Golden-тесты выполняются только на ubuntu-раннере, потому что рендер шрифтов зависит от платформы.

### 19.5 Источники данных профиля

- Новые переменные `.env.example`: `PUBLIC_API_URLS` (через запятую, обязательна), `SUPPORT_URL`, `WEB_URL`, `POLICY_FILE=config/policy.yaml`.
- `endpoints.api` берётся из `PUBLIC_API_URLS`, `endpoints.bot` — из `TELEGRAM_BOT_USERNAME`, `support` и `web` — из `SUPPORT_URL` и `WEB_URL`.
- `backend/config/policy.yaml` появляется в S0-08 и содержит `ClientPolicy`. S3-07 добавляет к нему применение `defaults` и `locked` в приложении.

### 19.6 Типы настроек

`SettingsKey` остаётся строковым enum с путями через точку. `SettingsPatch` — вложенный объект: `routing`, `dns`, `net`, `perApp`, `ping`, `connect`, `ui`, `whitelist`. Типы `routing`, `dns`, `net`, `perApp` совпадают с `TunnelSettings`. Остальные:

| Ключ | Тип |
|---|---|
| `ping.type` | `tcp \| url_test` |
| `ping.url` | string |
| `ping.timeoutMs` | int |
| `ping.onOpen` | bool |
| `connect.autoConnect` | bool |
| `connect.autoConnectStrategy` | `last_used \| lowest_ping \| random` |
| `connect.autostart` | bool |
| `ui.sortByPing` | bool |
| `ui.locale` | `system \| ru \| en` |
| `ui.theme` | `system \| light \| dark` |
| `whitelist.autoOnCellular` | bool |

`whitelist.autoOnCellular` не входит в `TunnelSettings`, а передаётся как `TunnelRequest.autoSwitch.enabled`.

### 19.7 VpnBridge

`VpnBridge` содержит методы `VpnHostApi`, кроме `listApps`, и два метода с разной реализацией на платформах:

```dart
Future<List<SelectableApp>> listSelectableApps(); // Android: listApps; Windows: listProcesses
Future<List<String>> syncRuleSets(List<RuleSetRef> ruleSets); // Android: скачивание в Dart; Windows: IPC syncRuleSets

class SelectableApp { final String id; final String label; }
```

`id` — имя пакета на Android и имя процесса на Windows.

### 19.8 Типы клиентов бэкенда

```go
type CreateUserInput struct {
    Username     string
    ExpiresAt    time.Time
    TrafficLimit int64
}

type UpdateUserInput struct {
    ExpiresAt    time.Time
    TrafficLimit int64
}

type InlineButton struct {
    Text         string
    URL          string // заполнено ровно одно из URL и CallbackData
    CallbackData string
}

type UpdateKind string

const (
    UpdateMessage      UpdateKind = "message"
    UpdateCallback     UpdateKind = "callback"
    UpdateBotBlocked   UpdateKind = "bot_blocked"
    UpdateBotUnblocked UpdateKind = "bot_unblocked"
)
```

`telegram.Update` получает поля `Kind UpdateKind` и `CallbackID string`. `UpdateBotBlocked` и `UpdateBotUnblocked` приходят из `my_chat_member`. Первый ставит `bot_blocked_at = now()`, второй и любое сообщение от пользователя сбрасывают его в `null`.

### 19.9 Вход и устройства

`POST /v1/auth/logout` отвечает 204 без тела.

`POST /v1/auth/telegram/verify` при существующем `installId`:

| Устройство | Результат |
|---|---|
| Этот аккаунт, активно | Тот же `deviceId`, новый токен |
| Этот аккаунт, отозвано | Проверка лимита; тот же `deviceId`, `revoked_at = null`, новый токен |
| Другой аккаунт | Проверка лимита нового аккаунта; тот же `deviceId`, `account_id` меняется, `revoked_at = null`, новый токен, старый токен перестаёт работать |

Лимит превышен → 409 `device_limit_reached`, устройство не меняется.

Нормализация ника: `^[a-z0-9_]{4,32}$`, потому что в Telegram есть коллекционные ники из 4 символов.

S1-07 добавляет минимальный экран `/settings` с кнопкой выхода. S3-01 заменяет его полными настройками.

### 19.10 Автопереключение

- Начальное состояние при `Start`: `net = other`, `override = false`, `effective` вычисляется по правилу §5.7. Хост отправляет `NetChanged` с текущей сетью сразу после старта.
- `no_whitelist_servers` отправляется только при изменении состояния: сеть стала `cellular` или `whitelistAvailable` сменился на `false` в сети `cellular`. Это согласует правило с инвариантом I6.

---

## 20. Поправки ядра v3

### 20.1 Закрытие стадии 0

- Стадия 0 закрыта без S0-09b: §19.1 разрешает старт стадии 1 без него.
- Метка `bootstrap` удалена. Любой PR с контрактными путями требует метку `contract-change` и бамп версии ядра.

---

## 21. Поправки ядра v4

### 21.1 Ключи Reality

- `VlessRealityParams.publicKey`: X25519, 32 байта, base64url без паддинга, 43 символа. `shortId`: hex, до 16 символов.
- Фикстуры и сид содержат ключи этого формата, потому что C1 пропускает их через `box.New`.

### 21.2 Уточнения §5.8

- Сборка берёт `effective = userMode` (§19.10). Группа `userMode` пуста → ошибка `no_servers_in_group`.
- Правило `perApp` на Windows стоит после правил пресета, перед `final`.
- `perApp.mode = include` без приложений → `config_invalid`. Android проверяет список после удаления собственного пакета.
- `routing.enabled = false` отключает пользовательские правила, пресет и rule sets.
- Собственный пакет на Android: `com.vpnclient.app`, из `applicationId`.

---

## 22. Поправки ядра v5

### 22.1 Операции ядра

- S1-02 реализует `core/bind`. Сигнатуры §5.9 не меняются.
- `Update`, `SetUserMode` и `SelectServer` вне `connected` ничего не делают и не возвращают ошибку.
- `Update` с отвергнутым запросом оставляет туннель работать.
- `SelectServer` с сервером вне группы → `config_invalid`. `SetUserMode` на пустую группу → `no_servers_in_group`.
- `upBps` и `downBps` — байты за интервал `traffic` (1 секунда).
- `URLTest` реализуется в S1-12.

### 22.2 Каталог данных `vpnsvc`

Служба работает из `%ProgramData%\vpnclient`. Относительные пути rule sets (§5.4) и `cache_file` резолвятся в нём.

---

## 23. Поправки ядра v6

### 23.1 Android-хост

- `onRevoke` доходит только до `VpnService`, а поверхность §5.9 заморожена. Хост останавливает ядро и сам отправляет `CoreEvent` типа `error` с кодом `revoked`.
- При `include` хост передаёт `VpnService.Builder` только список разрешённых пакетов, потому что Builder не принимает оба списка. Собственный пакет в этом режиме и так вне туннеля.
- Хост хранит последний принятый `TunnelRequest` в `noBackupFilesDir/last_request.json` для always-on и S3-05. Выход из аккаунта (S1-07) обязан удалить этот файл.

### 23.2 CI

Эмулятор получает согласие на VPN через `appops set <package> ACTIVATE_VPN allow`, потому что системный диалог в CI недоступен.

---

## 24. Поправки ядра v7

### 24.1 Служба

- `syncRuleSets` принимает только HTTPS, `id` по шаблону `^[a-z0-9][a-z0-9_-]{0,63}$` и `sha256` из 64 hex-символов. Размер файла ограничен 32 MiB. Файл заменяется только после проверки `sha256`, поэтому сбой оставляет прежнюю проверенную версию, а `id` не попадает в `ready`.
- `urlTest` по IPC возвращает `internal`, пока S1-12 не реализует его в ядре.
- `listProcesses` отдаёт одну запись на имя процесса без учёта регистра, отсортированно.
- `last_request.json` пишется только после принятого `start` или `update`. ACL ставится до записи содержимого.

### 24.2 Установщик

- Обновление останавливает службу до копирования файлов и не требует перезагрузки. На время обновления туннель обрывается.
- Удаление снимает службу, каталог `%ProgramData%\vpnclient` и неактивный адаптер `sing-tun`. Работающий адаптер может принадлежать другому приложению и остаётся.

---

## 25. Поправки ядра v8

### 25.1 Модель устройства при входе

- `TelegramLoginStart` получает обязательное поле `model: string`, 1..64 символа, потому что сообщение с кодом уходит до `verify`.
- Args `telegram_send_code`: `{loginId, code, model}`. Миграция не нужна: значение живёт в строке джоба вместе с кодом.
- Ник публичен, поэтому `model` заполняет кто угодно, а текст попадает в сообщение бота. Сервер заменяет на пробел всё, кроме букв, цифр, пробела и `()_+-`, и схлопывает пробелы, чтобы в сообщение нельзя было вставить ссылку или упоминание. Пустой результат: «неизвестное устройство».

### 25.2 Лимит по IP

- `httpapi.Deps.AuthRatePerMin`: фиксированное окно 60 с в памяти процесса на операции без токена. Превышение: 429 `rate_limited` с `retryAfterSec`.
- Адрес клиента: последний элемент `X-Forwarded-For`, потому что его дописывает Caddy, а порт API наружу не опубликован. Без заголовка: `RemoteAddr`. Адрес не попадает в логи и БД.

### 25.3 Правила входа

- Cooldown и лимит 5 кодов в час считаются на `telegram_id`. Превышение: 429 `rate_limited` с `retryAfterSec`.
- Пятая неверная попытка отвечает 410 `code_expired`.
- Неизвестный `loginId` и чужой `installId`: 410 `code_expired`, попытка не тратится.
- 409 `device_limit_reached` не тратит код: пользователь освобождает слот и повторяет ввод.
- Код: 6 цифр из криптостойкого генератора.
- `TelegramLoginVerify.model` и `appVersion`: до 64 символов, `appVersion` не пустой. Иначе 400 `validation_failed`.

---

## 26. Поправки ядра v9

### 26.1 Вход в `ApiClient`

- `ApiClient` (`app/lib/core/api`) получает `startTelegramLogin(TelegramLoginStart) → TelegramLoginChallenge`, `verifyTelegramLogin(TelegramLoginVerify) → AuthResult` и `logout()`.
- `ApiProblem` получает необязательные `botUrl`, `attemptsLeft` и `retryAfterSec` из тела проблемы, потому что экран входа показывает ссылку на бота, оставшиеся попытки и таймер.
- `FakeApiClient` отвечает на `start` и `verify` для любого ввода, чтобы `FAKE_API` работал без бэкенда, и падает с заданным `ApiException`.

### 26.2 Устройство

- `DeviceIdentity { platform: Platform, model: String, installId: String }` и `deviceIdentityProvider` в `app/lib/core/device`, потому что ветки по платформе живут только в `app/lib/core`.
- `installId`: случайный UUID v4 в secure storage. Выход его не удаляет, поэтому повторный вход получает тот же `deviceId` (§19.9).
- `model`: на Android `manufacturer model`, на Windows название продукта ОС, до 64 символов. Пустое значение заменяется именем платформы. Пакет `device_info_plus`.

### 26.3 Выход

- Pigeon `VpnHostApi` получает `@async void forgetLastRequest();`, `VpnBridge` — `Future<void> forgetLastRequest()`. Android удаляет `last_request.json` (§23.1). Windows ничего не делает: файл службы остаётся, в IPC v1 нет метода для него.
- Выход по шагам: `POST /v1/auth/logout` (сбой сети не мешает выходу), `stop`, `forgetLastRequest`, удаление кэша профиля, удаление токена.

### 26.4 Роуты и dev-токен

- `/login` строит `LoginScreen`, `/settings` строит `SettingsScreen` из `app/lib/features/auth`. `/settings/:section` остаётся заглушкой до S3-01.
- `AppConfig.devToken`, его запись в `main.dart` и `DEV_TOKEN` в `env/dev.json` удаляются: вход заменяет их, а токен из env возвращал сессию после выхода.

---

## 27. Поправки ядра v10

### 27.1 Экраны режимов

- Каждый экран режима в `app/lib/app/home_screen.dart` показывает `ConnectionPanel(mode: TunnelMode)` из `app/lib/features/connection` над `ServerSheet`, потому что таблица `PowerButton` из §2.1 требует кнопку на обоих экранах.
- Список серверов на экране «Белые списки» остаётся за S2-01.

### 27.2 Значения `TunnelRequest` до S3-01

- `settings`: `policy.defaults` поверх встроенных значений. Встроенные значения совпадают с `backend/config/policy.yaml`, плюс `tlsFragment` выключен, `excludeRoutes`, `rules` и `ruleSets` пустые, `perApp.mode = off`, `mtu = 1500`. S3-01 добавляет пользовательские значения и `locked`.
- `selected` пустой до S1-09: ядро берёт первый сервер группы по `sortWeight` (C3).
- `autoSwitch.enabled = policy.flags.autoWhitelist && whitelist.autoOnCellular`.
- `platform` из `DeviceIdentity` (§26.2), `log.level = warn`.
- В профиле нет серверов группы режима → приложение не зовёт `start` и показывает `no_servers_in_group`, потому что ядро отвергает запрос без серверов как `config_invalid`.

---

## 28. Поправки ядра v11

### 28.1 Экраны режимов

- Каждый экран режима в `app/lib/app/home_screen.dart` показывает `ServerPicker(group: TunnelMode)` из `app/lib/features/servers` вместо `ServerList` эталона, потому что карточка S1-09 требует список своей группы и выбор на каждом экране. Пункт §27.1 о списке «Белых списков» в S2-01 отменяется.
- За S2-01 остаются свайп, `PageDots`, клавиши ← → и их тесты.

### 28.2 Выбор сервера

- Приложение хранит выбор каждой группы в приватном каталоге приложения, выбор переживает перезапуск.
- `selected` несёт сохранённый выбор группы, если профиль держит этот сервер в этой группе. Иначе первый сервер группы по `sortWeight` в порядке профиля, как C3. Для пустой группы ключа нет. Тот же сервер подсвечен в списке.
- В `connected` выбор в любой группе зовёт `selectServer(group, serverId)`, чтобы последующий `setUserMode` попал на выбранный сервер. Вне `connected` выбор только сохраняется. В `connecting` и `disconnecting` плитки игнорируют тап, как `PowerButton`.
- Ошибка `selectServer` показывает баннер панели подключения по коду.

---

## 29. Поправки ядра v12

### 29.1 Параметры хоста панели

- `PanelHost.Params` несёт несекретные поля `VlessRealityParams` или `Hysteria2Params` в форме `openapi.yaml`, без `uuid` и `password`. Так их уже отдаёт fake-панель сида. S1-10 приводит ответ API панели к этой форме.
- `catalog_sync` декодирует их строго: неизвестное поле, в том числе `uuid` или `password`, делает хост невалидным. Каноническая форма уходит в `servers.params`, профиль добавляет к ней креды пользователя (§15.2).
- Проверки повторяют ядро, чтобы хост, который ядро отвергнет, не попал в профиль: `publicKey` и `shortId` по §21.1 (`shortId` — hex чётной длины), `flow` и `fingerprint` из enum, непустой `serverName`. Hysteria2: `portHopping.ports` — список портов и диапазонов в 1..65535, `intervalSec`, `upMbps` и `downMbps` больше нуля, `obfsSalamanderPassword` непустой. Адрес без пробелов, порт 1..65535.

### 29.2 `servers.yaml`

- Файл — YAML-список записей §6. `enabled` по умолчанию `true`. Строка получает `enabled = true`, только если `enabled` записи и `PanelHost.Enabled` оба истинны.
- Файл отвергается целиком, если в нём неизвестное поле, неверный или повторный `remnawaveHostUuid`, `group` вне `TunnelMode`, пустой `displayName`, `countryCode` не из двух латинских букв или `sortWeight` вне int32. Файл выкатывается одним артефактом, поэтому частичное доверие к нему не нужно.
- Пустой каталог пишется как `[]`. Пустой или отсутствующий файл — ошибка, потому что прочитанный как пустой он выключил бы все серверы.
- Нормализация: пробелы по краям строк обрезаются, `countryCode` переводится в верхний регистр, пустой `city` становится `null`, из `portHopping.ports` убираются пробелы.

### 29.3 `catalog_sync`

- Джоб сначала читает `servers.yaml` и `ListHosts`. Ошибка любого из них или повтор UUID хоста в ответе панели валит джоб, River его ретраит, таблица не меняется.
- Хост с записью, но с невалидными параметрами, пропускается, его строка выключается, остальные хосты синхронизируются. В лог уходит предупреждение с UUID хоста и причиной без значений полей.
- `content_hash`: sha256 полей `grp`, `protocol`, `display_name`, `country_code`, `city`, `address`, `port`, `params`, `sort_weight` после нормализации. `enabled` в хеш не входит: строка исчезнувшего хоста выключается без пересчёта хеша. Upsert меняет строку, если изменился `content_hash` или `enabled`, иначе `updated_at` остаётся прежним. `id` строки не меняется.
- Запись идёт одной транзакцией под `pg_advisory_xact_lock(-2)`. Две синхронизации с разными снимками панели иначе блокируют строки во встречном порядке и ловят deadlock. Отрицательные ключи — глобальные блокировки, положительные — Telegram ID.
- Сид пишет `content_hash` той же функцией, поэтому первый `catalog_sync` после `make seed` ничего не меняет.

### 29.4 Окружения

- Воркер при `PANEL_MODE=fake` и `APP_ENV=dev` берёт fake-панель с хостами сида. `fake` вне dev даёт пустую fake-панель, потому что сид только для dev. При `remnawave` воркер не регистрирует `catalog_sync` до S1-10 и пишет предупреждение.
- `contracts/fixtures/seed/catalog.yaml` — `servers.yaml` сид-серверов, тест держит его равным `seed.json`. `CATALOG_FILE` в `backend/.env.example` указывает на него. Значение по умолчанию в `config` остаётся `../infra/catalog/servers.yaml`.
- `infra/catalog/servers.yaml` — каталог staging и prod, до S1-13 это `[]`. Роль `api-host` копирует `infra/catalog`, Compose монтирует файл в воркер по пути `CATALOG_FILE` по умолчанию.

---

## 30. Поправки ядра v13

### 30.1 CI эмулятора

- Эмулятор получает раздел данных 4096 МБ (`disk-size`), потому что на части образов раннера нет 7,4 ГБ для раздела по умолчанию и эмулятор не загружается.
- Джоб эмулятора удаляет больше предустановленного ПО и печатает `df -h /`.
- `emulator_diagnostics.sh` ограничивает каждый вызов `adb` 60 секундами: зависший эмулятор не должен держать джоб до его лимита, при котором лог пропадает.

---

## 31. Поправки ядра v14

### 31.1 `URLTest` в ядре

- S1-12 реализует `URLTest` в `core/internal/runtime` и `core/bind`. Сигнатура §5.9 не меняется. `vpnsvc` берёт `urlTest` из runtime, пункт §24.1 о коде `internal` отменяется.
- `serverIDsJSON` — JSON-массив строк. Другой JSON → `config_invalid`.
- Ядро проверяет каждый сервер через его outbound `srv-<id>` запросом HEAD к `https://www.gstatic.com/generate_204`, тем же адресом, что `policy.ping.url` сида. Таймаут 5 с на сервер, параллельно не больше 8. `TunnelRequest` не несёт `ping.url` и `ping.timeoutMs`, поэтому S3-05 добавляет их бампом ядра.
- Результаты идут в порядке запроса, повторы `serverId` убираются. Каждый результат несёт `delayMs` или `error` из фиксированных слов: `timeout`, `failed`, `unknown_server` (сервера нет в запросе), `not_connected` (туннель не в `connected`, сеть не трогается). Текст ошибки sing-box в событие не попадает, потому что он может цитировать опции.
- Событие `url_test` только возвращается и в поток событий не уходит.

### 31.2 Пинг в приложении

- Тип пинга: `policy.defaults.ping.type`, иначе `tcp`. При `url_test` в `connected` приложение зовёт `VpnBridge.urlTest` один раз со всеми серверами профиля. Ошибка вызова или `tcp` → TCP-пинг.
- TCP-пинг: время установки TCP-соединения с `address:port`, таймаут `policy.defaults.ping.timeoutMs`, иначе `policy.ping.timeoutMs`. Таймаут и ошибка → `unreachable`. Не больше 8 соединений одновременно. Hysteria2 слушает только UDP, поэтому TCP-пинг оставляет такой сервер `unknown`.
- Пингуются все серверы профиля, потому что каждый экран режима показывает список своей группы. Пинг при открытии: один раз за запуск, когда в готовом профиле впервые есть серверы, если `policy.defaults.ping.onOpen` не `false`. Кнопка в шапке списка запускает пинг заново. Запуск во время идущего пинга игнорируется.
- `sortServers`: при включённой сортировке сначала серверы с `ms` по возрастанию, потом неизмеренные (`unknown`, `measuring`), потом `unreachable`. Равные сохраняют порядок `sortWeight`, а при равном весе порядок профиля. Сортировка выключена → порядок `sortWeight`. Сервер по умолчанию (C3, §28.2) от сортировки не зависит.
- Тумблер `ui.sortByPing` — `SettingsToggleTile` в шапке `ServerPicker` из `app/lib/features/servers` на обоих экранах. Значение: выбор пользователя, иначе `policy.defaults.ui.sortByPing`, иначе `true`. `ui.sortByPing` в `policy.locked` → тумблер заблокирован, значение из `defaults`.
- Выбор пользователя хранится как `SettingsPatch` в `user_settings.json` в приватном каталоге приложения. S3-01 забирает этот файл под все пользовательские настройки.
- `ServerPicker` берёт порядок серверов и значения пинга из `app/lib/features/ping`.

---

## 32. Поправки ядра v15

### 32.1 Автопереключение в ядре

- S2-02 реализует `OnNetworkChanged` в `core/bind`. Сигнатура §5.9 не меняется. Ошибку runtime `bind` отбрасывает, потому что у метода нет результата.
- Значение вне `NetType` → `config_invalid` в runtime, состояние не меняется.
- Вне `connected` `OnNetworkChanged` ничего не делает. `Start` сбрасывает сеть в `other` (§19.10), хост сообщает её заново.
- `SetUserMode` передаёт `UserModeSet` всегда, в том числе с текущим `userMode`. Так тап на экране режима пользователя при `effectiveMode = whitelist` на cellular ставит `override` (§2.1, третья строка таблицы).
- `Update` сохраняет `net` и `override`. Он передаёт `AutoSwitchSet`, `ServersUpdated` и `UserModeSet` только для изменившихся значений, иначе каждая смена настроек снимала бы `override`. Новый box стартует с селектором `proxy` на группе `effective`. События `mode` идут после `state` со статусом `connected`.
- Сбой переключения селектора → `internal`, состояние остаётся прежним, повтор того же события повторяет переключение.

### 32.2 Причины смены режима

| Событие | Смена `effective` | Причина |
|---|---|---|
| `NetChanged(cellular)` | → `whitelist` | `network_cellular` |
| `NetChanged(wifi \| ethernet \| other)` | → `userMode` | `network_wifi` |
| `UserModeSet` | любая | `user` |
| `AutoSwitchSet`, снявший `override` | → `whitelist` | `override_cleared` |
| `AutoSwitchSet(true)` | → `whitelist` | `network_cellular` |
| `AutoSwitchSet(false)` | → `userMode` | `user` |
| `ServersUpdated(true)` | → `whitelist` | `network_cellular` |
| `ServersUpdated(false)` | → `userMode` | `no_whitelist_servers` |

- `no_whitelist_servers` без смены группы: `from = to = effective`. Отправляется, когда автопереключение выбрало бы `whitelist` (`autoSwitch`, нет `override`, `userMode = regular`), но серверов нет, и сеть только что стала `cellular`. Включение `autoSwitch` на cellular без whitelist-серверов предупреждения не даёт, потому что §19.10 называет только две причины.
- Потеря whitelist-серверов на cellular при `effective = whitelist` всегда меняет группу и приходит одним событием с причиной `no_whitelist_servers`.

---

## 33. Поправки ядра v16

### 33.1 Клавиши на главном экране

- `ModePager` ловит ← → только при фокусе внутри своих страниц. Tab доводит фокус до кнопки настроек и точек `PageDots`, которые стоят над пейджером, и там стрелки только двигали фокус. Поэтому `app/lib/app/home_screen.dart` оборачивает шапку и `ModePager` в `ModeScreenKeys(index, count, onChanged, child)` из `app/lib/features/whitelist`.
- `ModeScreenKeys` переключает экран на соседний и на первом и последнем экране ничего не делает, как `ModePager`. Клавишу, которую обработал `ModePager`, он не видит, поэтому одно нажатие никогда не сдвигает экран на два.
- Стрелки, как свайп и клик по точке, не зовут `VpnBridge` (§2.1).

### 33.2 Раскладка S2-01

- Экран «Белые списки» уже собран по §27 и §28: `ConnectionPanel` и `ServerPicker(group: whitelist)`, `EmptyState` для пустой группы. S2-01 добавляет `ModeScreenKeys` и тесты карточки в `app/test/features/whitelist/`.

---

## 34. Поправки ядра v17

### 34.1 Тумблер автоперехода

- `AutoSwitchToggle` из `app/lib/features/whitelist` — `SettingsToggleTile` ключа `whitelist.autoOnCellular`. `app/lib/app/home_screen.dart` ставит его под `ConnectionPanel` экрана «Белые списки», `SettingsScreen` из `app/lib/features/auth` — в раздел «Подключение» над разделом «Аккаунт».
- Тумблер скрыт, пока профиль не готов и когда `policy.flags.autoWhitelist == false`.
- Значение: выбор пользователя, иначе `policy.defaults.whitelist.autoOnCellular`, иначе `true`. Ключ в `policy.locked` → тумблер заблокирован, значение из `defaults`. Выбор хранится в `user_settings.json` (§31.2).
- `TunnelRequest.autoSwitch.enabled = policy.flags.autoWhitelist && значение тумблера`. Пункт §27.2 об `autoSwitch.enabled` уточняется так.
- Смена значения в `connected` зовёт `update` с запросом, собранным для текущего `userMode`, потому что ядро узнаёт о тумблере только из запроса (§32.1). Вне `connected` значение только сохраняется, следующий `start` несёт его. Ошибка `update` показывает баннер панели подключения по коду, выбор остаётся сохранённым.

### 34.2 Событие `mode` в приложении

- Событие `mode` с причиной, отличной от `user`, переводит `ModePager` на экран `to`. Причина `user` экран не меняет: пользователь уже на экране режима или сам выключил автопереход.
- `ConnectionPanel` на обоих экранах показывает баннер о последнем событии `mode`: `network_cellular`, `network_wifi` и `override_cleared` — `info`, `no_whitelist_servers` — `warning`. Причина `user` баннер снимает.
- Баннер снимается, когда туннель выходит из `connected`, и при новом тапе по `PowerButton`.
- `home_screen.dart` слушает события через `ConnectionController` из `app/lib/features/connection`, потому что фичи не зависят от `app/lib/app`.

---

## 35. Поправки ядра v18

### 35.1 Запасные эндпоинты API

- `ApiEndpoints` в `app/lib/core/api` держит порядок адресов: `endpoints.api` последнего профиля, потом `API_BASE_URLS` сборки, без повторов. `ProfileRepository` сообщает ему адреса профиля из кэша до запроса и из каждого полученного профиля, поэтому устройство без доступа к основному домену доходит до запасного уже на первом запросе после запуска.
- `FallbackApiClient` в `app/lib/core/api` реализует `ApiClient` поверх `HttpApiClient` на каждый адрес и перебирает их по порядку. Таймаут соединения и ответа на каждый адрес — 9 с.
- `fetchProfile` переходит к следующему адресу при любом `ApiUnavailable`. `startTelegramLogin`, `verifyTelegramLogin` и `logout` переходят только при сбое соединения, когда запрос не ушёл: повторный `start` упирается в cooldown, а повторный `verify` тратит одноразовый код.
- `ApiProblem` останавливает перебор: сервер ответил.
- `ApiUnavailable` получает поле `requestSent: bool`. `false` — сбой соединения или его таймаут.
- Все адреса недоступны → `ApiUnavailable`. Профиль берётся из кэша (§15.2), без кэша — `ProfileFailed` и `ErrorView`.
- Каждый запрос начинает с первого адреса.

### 35.2 Rule sets

- Пункт S2-06 о rule sets из ассетов приложения переходит в S3-02: приложение начинает скачивать rule sets только там.

---

## 36. Поправки ядра v19

### 36.1 Staging на общем хосте

- Staging делит VPS с чужими сервисами, порт 443 занят. Caddy публикует HTTPS на `HTTPS_PORT` (staging: 8443, переменная `STAGING_HTTPS_PORT`), порт 80 остаётся для выдачи сертификата Let's Encrypt. `PUBLIC_API_URLS` несёт порт, если он не 443.
- Пока домена нет, имя API — поддомен sslip.io от IP хоста. Замена на свой домен меняет только секрет `STAGING_DOMAIN`.
- Роль `api-host` не трогает чужие контейнеры и сервисы хоста.

### 36.2 Бот на staging

- Без адреса для webhook бот работает в режиме `polling`: сервис `bot` в `infra/compose/api/compose.yaml` под профилем Compose `polling`, образ бэкенда собирает `cmd/bot`. `COMPOSE_PROFILES=polling` ставится, когда задан токен бота.
- Токен бота — секрет `STAGING_BOT_TOKEN`, ник — переменная `STAGING_BOT_USERNAME`. Токен попадает только в `.env` на хосте с правами `0600`.

### 36.3 Деплой

- Деплой включает переменная `STAGING_ENABLED = true`. Адрес хоста (`STAGING_HOST`) и имя API (`STAGING_DOMAIN`) — секреты: логи публичного репозитория маскируют только секреты.
- Роль входит в `ghcr.io` токеном джоба только на время `docker compose up` и выходит даже при ошибке, поэтому образ может оставаться приватным, а хост не хранит учётных данных реестра.
- Пользователь `deploy` с ключом `STAGING_SSH_KEY` и `sudo` без пароля создаётся на хосте один раз вручную.
- Джоб заканчивается проверкой `https://<STAGING_DOMAIN>:<порт>/healthz`.

---

## 37. Поправки ядра v20

### 37.1 APK для staging

- Workflow `staging-apk` запускается вручную и собирает release-APK для arm64 с подписью debug-ключом. `API_BASE_URLS` — `https://<STAGING_DOMAIN>:<STAGING_HTTPS_PORT>` из секретов, `FAKE_VPN` и `FAKE_API` выключены.
- Артефакт живёт один день. Тот, кто запустил сборку, удаляет его сразу после скачивания: репозиторий публичный, а APK несёт адрес staging.
- `app/env/staging.json` остаётся заглушкой, адрес в репозиторий не попадает.

### 37.2 Раскладка S1-13

- Staging получает одну ноду вместо двух. Панель Remnawave стоит на сервере ноды, потому что сервер бэкенда делит 2 ГБ памяти с чужими сервисами.
- Панель не публикуется наружу, вход в неё — через SSH-туннель. Порт 443/tcp сервера ноды занимает VLESS Reality.
- Имя сервера — `<страна>-<город>-<номер>` в нижнем регистре, например `se-sto-1`. Пользователь видит `displayName` из каталога.
- Адрес ноды в репозиторий не попадает: инвентарь Ansible берёт его из секретов, а `servers.yaml` хранит только UUID хоста панели.

---

## 38. Поправки ядра v21

### 38.1 Xray на ноде

- Нода запускает официальный Xray v26.6.27 поверх `xray` из образа. Архив релиза проверяется по SHA2-256 из его `.dgst`.
- Причина: sing-box 1.14.x не отправляет key share X25519MLKEM768, а Xray с v26.9.8 отвергает Reality без него (SagerNet/sing-box#4520).
- Когда sing-box выпустит исправление, бамп ядра поднимает тег sing-box в `core/go.mod` и снимает закрепление.

### 38.2 Hysteria2 на staging

- Inbound слушает 443/udp. Сертификат Let's Encrypt выписан на имя ноды в нашем домене. Salamander включён.
- `portHopping`: `{ports: "20000-50000", intervalSec: 30}`. Сервер принимает диапазон через NAT REDIRECT хоста на 443.
- Имя ноды и домен секретны, как адрес ноды (§37.2).

### 38.3 Пароль Hysteria2 в Remnawave

- Remnawave выдаёт пользователю пароль Hysteria2, равный его `vlessUuid`. S1-10 записывает это в ADR и берёт `Hysteria2Auth` оттуда.

### 38.4 Webhook бота на staging

- Staging принимает апдейты бота через webhook. Пункт §36.2 о polling отменяется для staging, polling остаётся для dev.
- Роль `api-host` один раз генерирует `TELEGRAM_WEBHOOK_SECRET` на хосте API и хранит его там с правами `0600`. В GitHub секрет не попадает.
- Каждый деплой зовёт `setWebhook` с адресом `https://<STAGING_DOMAIN>:<STAGING_HTTPS_PORT>/telegram/webhook` и `secret_token`. Telegram принимает webhook только на портах 443, 80, 88 и 8443, поэтому `STAGING_HTTPS_PORT` берётся из них.

### 38.5 Плейбук нод и смоук

- Роли `remnawave-panel` и `remnawave-node` запускаются вручную с машины разработчика. Инвентарь, адрес и имя ноды берутся из локальных переменных, в репозиторий не попадают. CI только прогоняет `ansible-lint`.
- `infra/scripts/smoke-nodes.sh` берёт креды пробного пользователя с хоста по SSH и проверяет через sing-box ответ 204 на `https://www.gstatic.com/generate_204` по VLESS Reality, по Hysteria2 напрямую и по Hysteria2 с port hopping. Плейбук нод запускает его в конце.

---

## 39. Поправки ядра v22

### 39.1 Клиент панели

- Спецификация — `contracts/remnawave/openapi-3.4.8.json`, файл `/opt/app/openapi.json` из образа `remnawave/backend:3.4.8` без изменений, sha256 `b8c1480ab310da0af0f802f8d59b17766e6097ad5b5d6b83eb0bb9829e83b89b`. Апгрейд панели заменяет файл и бампает ядро (§3).
- `make gen` генерирует `backend/internal/gen/remnawave` по `backend/oapi-codegen.remnawave.yaml`: модели и `client-with-responses`, только операции `UsersController_getUserByUsername`, `UsersController_createUser`, `UsersController_updateUser`, `HostsController_getHosts`, `ConfigProfileController_getAllInbounds`. Генератор берёт только нужные операции, потому что спецификация описывает 162 пути.
- Каждый запрос несёт `X-Forwarded-For: 127.0.0.1` и `X-Forwarded-Proto: https`: панель за туннелем видит обычный HTTP и без этих заголовков отвергает API-токен.

### 39.2 Пользователь панели

- В Remnawave 3.4.8 у пользователя нет UUID, только числовой `id`. `PanelUser.UUID uuid.UUID` заменяется на `PanelUser.ID int64`, сигнатура меняется на `UpdateUser(ctx, id int64, in UpdateUserInput)`.
- Миграция `00002`: `panel_users.remnawave_uuid uuid` → `remnawave_id bigint not null unique`. Строки в таблице есть только в dev-сиде, поэтому миграция падает, если таблица не пуста: dev-базу пересоздают, `make seed` пишет заново. Поле сида `remnawaveUuid` становится `remnawaveId`.
- `CreateUser` шлёт `username`, `expireAt`, `trafficLimitBytes`, `trafficLimitStrategy = NO_RESET`, `status = ACTIVE` и `activeInternalSquads = [REMNAWAVE_SQUAD_UUID]`, потому что пользователь без internal squad не получает ни одного inbound.
- Новая переменная `.env.example`: `REMNAWAVE_SQUAD_UUID`, обязательна при `PANEL_MODE=remnawave`.
- `Hysteria2Auth = vlessUuid` (§38.3). `ErrNotFound` — 404, `ErrConflict` — ответ панели «имя занято», `ErrUnavailable` — 5xx, таймаут, сеть. Остальные ответы — ошибка без ретрая.

### 39.3 Хосты панели

- `ListHosts` берёт `GET /api/hosts` и `GET /api/config-profiles/inbounds` и связывает хост с inbound по `inbound.configProfileInboundUuid`.
- `vless_reality` — inbound `vless` с `network = tcp` и `security = reality`: `flow = xtls-rprx-vision`, `serverName` из `sni` хоста, иначе `realitySettings.serverNames[0]`, `shortId = shortIds[0]`, `fingerprint` из хоста, иначе `chrome`. `publicKey` — X25519 от `realitySettings.privateKey`: панель отдаёт только приватный ключ. Приватный ключ не хранится и не логируется.
- `hysteria2` — inbound `hysteria` с `version = 2`: `serverName` из `sni` хоста, иначе адрес хоста; `obfsSalamanderPassword` из `streamSettings.finalmask.udp` с `type = salamander`.
- Хост на inbound другого типа в ответ `ListHosts` не попадает, и `catalog_sync` выключает его строку как исчезнувшую. `Enabled = !isDisabled && !isHidden`.
- Решение записано в `docs/adr/0001-remnawave-panel-fields.md`.

### 39.4 Port hopping в каталоге

- Запись `servers.yaml` получает необязательное поле `portHopping: {ports, intervalSec}` по правилам §29.1. Панель port hopping не хранит.
- `catalog_sync` кладёт его в `params` хоста `hysteria2`, поэтому поле входит в `content_hash`. `portHopping` у хоста другого протокола делает хост невалидным (§29.3).

### 39.5 SSH-туннель к панели на staging

- Панель и node_exporter ноды слушают только loopback (§37.2). Сервис `panel-tunnel` в `infra/compose/api/compose.yaml` (alpine с `openssh-client`, образ собирается рядом) держит `ssh -N -L 0.0.0.0:3000:127.0.0.1:3000 -L 0.0.0.0:9100:127.0.0.1:9100` к серверу ноды с `ExitOnForwardFailure`, `ServerAliveInterval` и `restart: unless-stopped`. Хост API не меняется (§36.1).
- Воркер ходит на `REMNAWAVE_BASE_URL=http://panel-tunnel:3000`, Prometheus скрейпит `panel-tunnel:9100`. Порты наружу не публикуются.
- На сервере ноды пользователь `panel-tunnel` без shell, ключ в `authorized_keys` с `restrict,port-forwarding,permitopen="127.0.0.1:3000",permitopen="127.0.0.1:9100"`. Его создаёт роль `remnawave-node`.
- Секреты GitHub: `STAGING_NODE_HOST`, `STAGING_PANEL_SSH_KEY`, `STAGING_NODE_KNOWN_HOSTS` (ключ хоста закреплён, `StrictHostKeyChecking=yes`), `STAGING_REMNAWAVE_TOKEN`, `STAGING_REMNAWAVE_SQUAD_UUID`. Роль `api-host` кладёт ключ и known_hosts на хост с правами `0600`.
- Staging ставит `PANEL_MODE=remnawave`. Воркер регистрирует `catalog_sync` с клиентом панели, предупреждение из §29.4 снимается. `infra/catalog/servers.yaml` получает UUID хостов `se-sto-1-vless` и `se-sto-1-hy2`.

---

## 40. Поправки ядра v23

### 40.1 Стек TUN на Android

- На Android ядро всегда ставит `stack: gvisor`. `net.tunStack` действует только на Windows. Пункт §5.8 о `stack` уточняется так.
- Причина: стеки `system` и `mixed` принимают TCP сокетом процесса приложения, а приложение исключено из своего VPN (§5.8, §21.2). Ответ такого сокета уходит в физическую сеть мимо `tun0`, рукопожатие не завершается, и через туннель проходит только UDP. Так было на Galaxy A22 с Android 12 (issue #82).
- Инвариант C5 дополняется: `platform = android` ⇒ `stack = gvisor`; `platform = windows` ⇒ `stack = net.tunStack`.

### 40.2 Сеть по умолчанию на Android

- Монитор интерфейса для sing-box и `NetworkMonitor` (§5.7) следят за лучшей сетью без VPN: запрос с `NET_CAPABILITY_NOT_VPN`, `registerBestMatchingNetworkCallback` на API 31+ и `requestNetwork` ниже, как официальный клиент sing-box.
- Причина: `registerDefaultNetworkCallback` после подъёма туннеля отдаёт приложению его же `tun0`, хотя приложение исключено из VPN. sing-box остаётся без интерфейса по умолчанию, и все исходящие соединения падают с `no available network interface`.

---

## 41. Поправки ядра v24

### 41.1 Сервер заводится в панели

- Сервер добавляется одним хостом в панели Remnawave. `catalog_sync` берёт метаданные из хоста, потому что панель уже хранит название, описание, теги и порядок, а запись в `servers.yaml` требовала PR и деплоя на каждый сервер.
- `PanelHost` получает поля `Remark string`, `Description string` (`serverDescription`, пусто, если не задано), `Tags []string` и `ViewPosition int`.

| Поле `servers` | Хост панели |
|---|---|
| публикуется ли | ровно один тег `COUNTRY:<XX>` |
| `country_code` | `<XX>` из `COUNTRY:<XX>`, две латинские буквы |
| `grp` | тег `WHITELIST` → `whitelist`, иначе `regular` |
| `display_name` | `remark` без пробелов по краям, не пустой |
| `city` | `serverDescription` без пробелов по краям, пустой → `null` |
| `sort_weight` | `viewPosition`, в пределах int32 |
| `portHopping` | тег `HOP:<ports>:<intervalSec>`, только у `hysteria2` |
| `enabled` | `!isDisabled && !isHidden` (§39.3) |

- Панель пускает в тег только `A-Z0-9_:`, поэтому в `HOP` знак `_` заменяет `-` диапазона: `HOP:20000_50000:30`. Список портов через запятую тегом не задаётся. Значение проверяется по правилам §29.1.
- Хост без тега `COUNTRY:` не для приложения: он не публикуется, и `catalog_sync` выключает его строку как исчезнувшую, без предупреждения. Хост с тегом `COUNTRY:`, но с ошибкой (два тега `COUNTRY:`, неверный код страны, пустой `remark`, два тега `HOP:`, `HOP:` у VLESS или с неверным значением) пропускается с предупреждением по §29.3.
- Остальные теги принадлежат другим пользователям панели и не читаются.

### 41.2 Без `servers.yaml`

- `infra/catalog/servers.yaml`, `contracts/fixtures/seed/catalog.yaml`, переменная `CATALOG_FILE`, монтирование файла в воркер и его копирование ролью `api-host` удаляются. Пункты §6 о `servers.yaml`, §29.2, §39.4, а также пункты §29.3 и §29.4 о чтении файла отменяются.
- Сид-хосты fake-панели несут теги и тексты своих серверов из `seed.json`, поэтому первый `catalog_sync` после `make seed` по-прежнему ничего не меняет.
- Роль `remnawave-panel` создаёт хосты ноды с `remark` и `serverDescription` из переменной инвентаря `node_city`, тегом `COUNTRY:` из `node_country` и тегом `HOP:20000_50000:30` у Hysteria2 (§38.2). Хост, созданный до v24 и без тега `COUNTRY:`, роль помечает один раз. Помеченный хост роль больше не трогает: правки в панели остаются. Хосты ищутся по inbound и адресу, а не по `remark`.

---

## 42. Поправки ядра v25

### 42.1 Обновление тестового APK поверх прежнего

- Тестеры получают APK из закрытого Telegram-канала и ставят новую сборку поверх прежней, без удаления и повторного входа. Android принимает обновление только с тем же ключом подписи и большим `versionCode`.
- `staging-apk` подписывает сборку ключом из секретов `STAGING_KEYSTORE_B64` (PKCS12 в base64, alias `vpnclient`) и `STAGING_KEYSTORE_PASSWORD`. Без ключа workflow падает, а не подписывает debug-ключом: такую сборку нельзя поставить поверх прежней. Пункт §37.1 о debug-ключе отменяется.
- `app/android/app/build.gradle.kts` берёт ключ из переменных `RELEASE_KEYSTORE` и `RELEASE_KEYSTORE_PASSWORD`. Без них release-сборка подписывается debug-ключом, как раньше.
- `versionCode` — номер запуска `staging-apk` (`--build-number`), поэтому каждая сборка выше прежней.
- Ключ хранится у владельца вне репозитория. Потеря ключа заставит каждого тестера удалить приложение и войти заново.

### 42.2 Размер тестового APK

- `staging-apk` собирает ядро только для `android/arm64` (`ANDROID_TARGET`): ядро для эмулятора x86_64 добавляло к APK 65 МБ. `make core-android` по умолчанию собирает обе архитектуры, как раньше.

### 42.3 Пробный период на staging

- Роль `api-host` ставит `TRIAL_DAYS=30`: трёх дней тестерам мало. Срок действует для аккаунтов, созданных после деплоя.
