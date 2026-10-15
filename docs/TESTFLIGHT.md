# ElementalCube — alpha 0.1.0 (12)

Капля — гладкий куб из воды с мягкими углами, без шерсти. Обновлены перенос жидкости, её поверхность, отделение капель и испарение. Прозрачные пластины за волной удалены; вода заполняет испарённую полость через расчёт течения. [Физика и источники](PHYSICS.md#сборка-12-поверхность-и-перенос-воды).

## Статус — 15 октября 2026

Сборка **0.1.0 (12)** загружена и обработана Apple: **VALID**. Build ID `f706392b-2394-42ba-a8f8-b667d0b5d44a`.

- **ElementalCube Internal**: **IN_BETA_TESTING**. Группа и прямое назначение существующему внутреннему тестеру подтверждены. Новых приглашений нет; прежние сборки сохранены.
- **ElementalCube Alpha**: 12 заменила 11 во внешней группе; статус **READY_FOR_BETA_SUBMISSION**.
- **Внешняя проверка**: Отправка получила `422 ANOTHER_BUILD_IN_REVIEW`: Apple ещё проверяет другую сборку этой версии. Старая проверка не отменялась. Внешняя установка ждёт Apple.

[Карточка Apple](https://appstoreconnect.apple.com/apps/6822921592/testflight) · [Внешняя группа](https://testflight.apple.com/join/snm99FQh).

## Установка

TestFlight → ElementalCube → **0.1.0 (12)**. Если нужно: **Предыдущие сборки → 0.1.0 → 12 → Установить**. В игре должно быть **АЛЬФА · 12**. Снимок с отметкой 8 показывает прежнюю установленную версию.

## Карточка и снимки

Русское и английское описания и What to Test сборки 12 обновлены. Notes описывают управление и воду этой сборки отдельно от прежней 4; частные контакты не менялись.

Apple подтвердила **COMPLETE для 12 снимков**: четыре iPhone и два iPad 13″ на каждом языке. Только после этого заменены 16 прежних собственных снимков. GIF — запись реальной симуляции для GitHub, в Apple не загружалась.

[Нативные снимки и запись воды](../Previews/alpha12) · [Тексты карточки](APP_STORE_CARD.md) · [Проверки](QA-ALPHA12.md).

## Артефакты

- Исходники: f6762bbb6e0f7ceeb45ccb4be015f5888a4907f6, тег `v0.1.0-alpha.12`.
- Архив: `build/alpha12/ElementalCube.xcarchive`.
- IPA: `build/alpha12/Export/ElementalCube-iOS.ipa`.
- SHA-256: 4b8b94d7726f44406564dd5fdeb5bd053857eb3b02e9d77101ab044e722d4075.
- Bundle `com.weavatrix.elementalcube`, версия `0.1.0`, build `12`, iPhone/iPad `[1,2]`, iOS 16+.
- Строгая подпись, ARCHIVE, EXPORT, VERIFY и UPLOAD подтверждены без ошибок; хеш IPA после загрузки не изменился.

```sh
ELEMENTAL_BUILD_NUMBER=12 ELEMENTAL_RELEASE_DIR=build/alpha12 ./scripts/testflight.sh prepare
ELEMENTAL_RELEASE_DIR=build/alpha12 ./scripts/testflight.sh validate
ELEMENTAL_RELEASE_DIR=build/alpha12 ./scripts/testflight.sh upload
```

Ключи и бинарные файлы не входят в Git. CI/CD нет, GitHub Actions выключен. Временный iPad этой задачи удалён, исходный iPhone-симулятор возвращён в выключенное состояние. Mac-версия 12 собрана отдельно и сохранена.

## Предыдущие сборки

**11**: Build ID `dcc81c74-0a16-4e5d-9681-dd0d70463d05`, тег `v0.1.0-alpha.11`, SHA-256 `42a56074bc3e784bb027b6055f8c665d91ba7ad0b246b1333c800e85e5046e4d`. Сохраняется во внутренней группе. [Проверки](QA-ALPHA11.md) · [Снимки](../Previews/alpha11).


**10** подготовлена локально и закреплена тегом, но не загружалась в Apple: до выпуска уточнялись материалы и горение. [Архив предрелиза](../Previews/alpha10).

**9**: Build ID `bec26815-325c-4ad5-95e1-11ff4fe36b9b`, тег `v0.1.0-alpha.9`, SHA-256 `5b0e674d79645ea9701d8251fad88d2a1ccb4ebe8d999658f872ed269540a5c6`. Сохраняется во внутренней группе. [Проверки](QA-ALPHA9.md).

**8**: Build ID `fd7ea0a0-866f-445c-b917-7af1aa3fee85`, тег `v0.1.0-alpha.8`, SHA-256 `e24a39554dbd030016442da17adbd7efa253d987bfff91654810b0da48923149`. [Проверки](QA-ALPHA8.md).
