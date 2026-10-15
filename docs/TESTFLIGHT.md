# ElementalCube — alpha 0.1.0 (9)

Контрольная сборка 9: анимированные портреты, бесплатные пассивки, изучаемые направленный и двойной прыжки, постепенный лёд, физические брызги, возгорание и иммунитет. В этой сборке базовый прыжок ещё вызывается коротким тапом по кубику. Последующее уточнение управления — свайп по экрану — разрабатывается для следующего выпуска.

## Статус — 15 октября 2026

Сборка **0.1.0 (9)** загружена, проверена и обработана Apple: **VALID**. Build ID `bec26815-325c-4ad5-95e1-11ff4fe36b9b`.

- **ElementalCube Internal**: 9, **IN_BETA_TESTING**; подтверждены группа и прямое назначение существующему внутреннему тестеру. Новых приглашений нет. Сборки 8–4 сохранены.
- **ElementalCube Alpha**: 9 заменила 8 во внешней группе.
- **Внешняя проверка**: 9 **READY_FOR_BETA_SUBMISSION**. Запрос получил `422 ANOTHER_BUILD_IN_REVIEW`, поскольку сборка 4 уже проверяется Apple. Проверка 4 не отменялась.

[Карточка Apple](https://appstoreconnect.apple.com/apps/6822921592/testflight) · [Внешняя группа](https://testflight.apple.com/join/snm99FQh). Внешняя установка требует одобрения Apple.

## Установка

TestFlight → ElementalCube → **0.1.0 (9)**. При необходимости: **Предыдущие сборки → 0.1.0 → 9 → Установить**. В игре отображается **АЛЬФА · 9**. Доступность сборки не подтверждает её фактическую установку на телефоне.

## Карточка и снимки

Русская и английская карточки и What to Test сборки 9 сохранены. Notes различают управление проверяемой 4 и более новой 9; частные контакты сохранены.

Apple подтвердила **COMPLETE для 12 новых снимков**: четыре iPhone и два iPad 13″ на каждом языке. Только после завершения обработки заменены 10 наших прежних снимков. Галерея пяти портретов предназначена для локального QA и в карточку Apple не загружалась.

[Снимки и GIF](../Previews/alpha9) · [Тексты](APP_STORE_CARD.md) · [Проверки](QA-ALPHA9.md).

## Артефакты

- Исходники: `bb7039a5fdc9c95353bac1a041d59e117d6bbe86`, тег `v0.1.0-alpha.9`.
- Архив: `build/alpha9/ElementalCube.xcarchive`.
- IPA: `build/alpha9/Export/ElementalCube-iOS.ipa`.
- SHA-256: `5b0e674d79645ea9701d8251fad88d2a1ccb4ebe8d999658f872ed269540a5c6`.
- Bundle `com.weavatrix.elementalcube`, версия `0.1.0`, build `9`, iPhone/iPad `[1,2]`, iOS 16+.
- Строгая подпись подтверждена; `ARCHIVE SUCCEEDED`, `EXPORT SUCCEEDED`, `VERIFY SUCCEEDED with no errors`, `UPLOAD SUCCEEDED with no errors`.

```sh
ELEMENTAL_BUILD_NUMBER=9 ELEMENTAL_RELEASE_DIR=build/alpha9 ./scripts/testflight.sh prepare
ELEMENTAL_RELEASE_DIR=build/alpha9 ./scripts/testflight.sh validate
ELEMENTAL_RELEASE_DIR=build/alpha9 ./scripts/testflight.sh upload
```

Ключи и подписанные бинарные файлы не попадают в Git. CI/CD не используется. Временный iPad-симулятор, созданный для QA 9, удалён; исходные снимки, результаты тестов, архив и IPA сохранены.

## Предыдущая альфа 8

Build ID `fd7ea0a0-866f-445c-b917-7af1aa3fee85`, тег `v0.1.0-alpha.8`, SHA-256 `e24a39554dbd030016442da17adbd7efa253d987bfff91654810b0da48923149`. Сохраняется во внутренней группе. [Проверки](QA-ALPHA8.md).
