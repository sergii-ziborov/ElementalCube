# Иллюстрации предметов — альфа 15

Созданы встроенным инструментом imagegen (`builtin`), 15 октября 2026. Два отдельных оригинала с прозрачным фоном. Итоговые PNG: 512 × 512 RGBA, уменьшение исходника с сохранением прозрачности; предметы не вырезались из чужого изображения. В мире используются соответствующие объёмные формы из `Geometry.swift`.

## traveler-charm

[Ассет](../Sources/ElementalCube/SkillArt/item-traveler-charm.png)

Промпт:

```text
Use case: stylized-concept. Asset type: a single premium inventory item illustration for ElementalCube, a cozy kawaii elemental cube game. Subject: a small worn dark meteorite talisman pendant, uneven chunky square stone with two shallow craters, inset warm gold spiral rune and simple braided cord loop, moss green edge accents. Painterly polished 3D game item, friendly rounded chunky silhouette, tactile stone and bronze, soft upper-left light, three-quarter front view. Isolated centered object fills 76 percent of square canvas, generous transparent padding, true transparent background, no ground plane, no badge, no text, no numbers, no crystals, no face. Must read as a protective stone pendant rather than a gem.
```

## deep-relic

[Ассет](../Sources/ElementalCube/SkillArt/item-deep-relic.png)

Промпт:

```text
Use case: stylized-concept. Asset type: a single premium inventory relic illustration for ElementalCube, a cozy kawaii elemental cube game. Subject: Heart of the Depths, an ancient circular bronze diving astrolabe amulet, substantial weathered bronze ring surrounding a luminous turquoise miniature water vortex and small pearl, tiny engraved wave grooves, three sculpted shell fins, brass suspension eye at top. Friendly rounded chunky silhouette, painterly polished 3D adventure-game item, soft upper-left light, subtle teal internal glow, three-quarter front view, beautifully readable at small icon sizes. Isolated centered object fills 76 percent of square canvas, generous transparent padding, true transparent background, no ground plane, no frame or badge, no text or numbers, no crystals, no diamonds, no face. Clearly a rare circular mechanical ocean relic, not a blue gem.
```

## Проверка файлов

| Предмет | Исходный imagegen PNG | SHA-256 итогового ассета |
| --- | --- | --- |
| Каменный оберег | `exec-b8188c86-b685-49a3-8833-819b540019e4.png` | `7852f86d6ce55bc6160fa20c537e9e66f9c97b14add4b2120d17d315f6da2526` |
| Сердце глубин | `exec-7e50d0af-beb7-4092-b9d0-8c70136786d4.png` | `827e382f6f7afb851cc6686ea0d82946c7e4ee43a86b454211e7db1b804ded9b` |

Оригиналы сохранены в локальной папке generated_images этого чата. В репозитории находятся игровые ассеты; отдельная генерация персонажей не производилась.
