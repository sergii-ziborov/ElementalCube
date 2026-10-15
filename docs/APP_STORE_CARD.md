# ElementalCube — материалы карточки Apple

Версия альфы: **0.1.0 (6)**. Одно приложение для iPhone и iPad. Карточка [App Store Connect](https://appstoreconnect.apple.com/apps/6822921592/testflight) заполнена на русском и английском, включая задания сборки 6. Сборка прошла обработку и доступна внутренней группе; [внешняя альфа](https://testflight.apple.com/join/snm99FQh) ожидает проверки Apple. В карточке сохранены 10 принятых Apple снимков сборки 6.

## Данные приложения

| Поле | Значение |
| --- | --- |
| Name | ElementalCube |
| Apple ID | `6822921592` |
| Bundle ID | `com.weavatrix.elementalcube` |
| SKU | `ElementalCube-iOS` |
| Primary language | Russian |
| Platform | iOS |
| Version | 0.1.0 |
| Category | Games / Puzzle / Adventure |
| Copyright | 2026 Sergii Ziborov |

- [Поддержка](https://github.com/sergii-ziborov/ElementalCube/issues)

- [Страница игры](https://github.com/sergii-ziborov/ElementalCube)

- [Конфиденциальность](https://github.com/sergii-ziborov/ElementalCube/blob/main/docs/PRIVACY.md)


Иконка: [PNG 1024 × 1024](../Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png). Физика воды и моста: [сборка 6](../Previews/physics6). Шерсть: [сборка 5](../Previews/fur5). Предыдущая галерея пяти форм сохранена в [архиве альфы 4](../Previews/alpha4). [Архивные размеры Apple](../Previews/app-store) относятся к сборкам 2 и 3.


## Русский

### Подзаголовок

```text
Маленький куб. Большой мир.
```

### Промотекст

```text
Пять стихий, пять характеров: замораживайте воду касанием, скользите над ней, исследуйте дно и испаряйте водоём огнём. Физическая песочница с пушистым героем.
```

### Ключевые слова

```text
куб,физика,прыжки,головоломка,лёд,вода,платформер,пушистик,приключение
```

### Описание App Store

```text
Маленький куб. Большой мир.

Выберите одну из пяти стихий и исследуйте тихий берег. Льдинка сразу создаёт ледяную опору при касании воды и затем постепенно расширяет лёд; Капля плавает; Ветерок скользит над водой; Камушек тонет и находит подводные проходы; Огонёк сжигает горючее и испаряет воду, теряя здоровье.

Начальная пассивная способность уже назначена и работает автоматически. Нажатие на название открывает описание. Здоровье и мана всегда видны; выбирайте, где тратить силы.

Потяните и отпустите, чтобы прыгнуть по выбранной дуге. Катитесь по траве, толкайте и опрокидывайте плавучий ящик, раскачивайте подвесной мост, скользите по льду и плывите к берегу. Доберитесь до флага, соберите три кристалла или отправьтесь каменной формой за глубинной реликвией.

Кубик реагирует на ваши действия: сосредотачивается перед прыжком, радуется находкам и встряхивает мокрую шерсть. Пряди спереди и по бокам меняются от ветра, движения и намокания. Мягкая трава и твёрдый камень по-разному встречают его после полёта; поддерживаемые iPhone добавляют тактильный отклик.

Это ранняя альфа ElementalCube: одна карта и пять форм для проверки управления и физики. Обучение, эволюция, арены и сохранение прохождения ещё не реализованы.

Игра работает без регистрации, рекламы и игрового сервера. Поддерживаются iPhone и iPad, портретная и горизонтальная ориентации. Настройки, выбранная форма сохраняются.
```

### Описание TestFlight

```text
Добро пожаловать в ElementalCube 0.1.0 (6)!

Ящик падает, вращается и вытесняет воду. Шесть секций подвесного моста прогибаются под весом куба. Жидкость и предметы обмениваются импульсами через расчёт давления.

Льдинка сразу замораживает опору под собой при первом касании воды; дальше холод растёт постепенно. Начальные пассивные способности назначены автоматически. Нажатие на название открывает только описание.

Пять форм, здоровье и мана, мягкая шерсть, ветер и намокание. Выбор другой формы начинает новую попытку. Игра работает без регистрации и игрового сервера. Интерфейс на русском.

Одна тестовая карта; дерево навыков, обучение, эволюция и арены ещё не реализованы. Особенно важны ощущения управления и производительность на физических iPhone/iPad.
```

### Что проверять — сборка 6

```text
Альфа 0.1.0 (6) — вода и предметы.

• Столкните ящик с берега стрелками. Проверьте падение, вращение, плавучесть, волны и столкновения с кубом.
• Прыгните на подвесной мост разными формами. Доски должны прогибаться, оставаться соединёнными и постепенно успокаиваться. Посмотрите на мост снизу.
• Вода должна доходить до берегов и погружённых предметов; движение ящика должно создавать течение и волну.
• Льдинка: при первом касании воды сразу возникает опора. Куб не должен сначала погружаться. Дальше лёд растёт локально; после ухода медленно тает.
• Нажмите «Морозное касание»: только описание, без переключателя экипировки. Все начальные пассивные способности уже назначены.
• Вода плавает, воздух скользит, камень проходит по дну под мостом и выходит по склону, огонь испаряет воду с потерей здоровья.
• Проверьте здоровье и ману, шерсть, ветер, намокание, прыжки в обе стороны, поворот устройства и возврат из фона.

В отзыве укажите модель устройства, форму, место проблемы и плавность игры.
```

## English

### Subtitle

```text
Small cube. Big world.
```

### Promotional text

```text
Five elements, five personalities. Freeze water by touch, glide above it, explore the bottom, or evaporate a pond with fire in a playful physics sandbox.
```

### Keywords

```text
cube,physics,platformer,ice,water,jump,puzzle,adventure,cozy
```

### App Store description

```text
Small cube. Big world.

Choose one of five elements and explore a quiet shore. Ice immediately forms support on first water contact, then gradually spreads the freeze. Water floats. Air slides above the surface. Stone sinks into underwater passages. Fire burns fuel and evaporates water at a health cost.

Your starting passive is already assigned and works automatically. Tap its name to read the description. Health and mana are visible from the start.

Drag and release to jump along your chosen arc. Roll over grass, push and tip a floating crate, and load a suspended bridge, slide on ice, and swim back to shore. Reach the flag, collect three crystals, or take Stone through the passage to a deep relic.

Your cube has a personality: it focuses before a jump, celebrates discoveries, and shakes its wet fur. Strands on the front and sides react to wind, motion, and water. Soft grass and hard stone create different landings. Supported iPhones add tactile feedback.

This is an early ElementalCube alpha with one map and five forms. Training, evolution, arenas, and saved playthroughs are not available yet.

No account, ads, or game server connection is required. Designed for iPhone and iPad in portrait and landscape. Settings and selected form persist locally.

The current in-game interface is in Russian.
```

### TestFlight description

```text
Welcome to ElementalCube 0.1.0 (6)!

The crate falls, rotates and displaces water. Six suspended bridge sections bend under the cube’s weight. Liquid pressure exchanges momentum with moving objects.

Ice immediately forms support on first water contact; further freezing spreads gradually. Starting passives are assigned automatically. Tap an ability name to read its description.

Five forms, health and mana, soft fur, wind and wetness. Changing form starts a new attempt. No account or game server is required. The interface is currently in Russian.

One test map. The skill tree, training, evolution and arenas are not implemented yet. Please focus on controls and performance on physical iPhones and iPads.
```

### What to test — build 6

```text
Alpha 0.1.0 (6): water and objects.

• Push the crate off the bank with the movement buttons. Check falling, rotation, buoyancy, waves and collisions with the cube.
• Jump onto the suspended bridge with different forms. Boards should bend, remain connected and settle. Inspect their undersides.
• Water should meet banks and submerged objects. Moving objects should create flow and waves.
• Ice: support should form immediately on first water contact, before sinking. Further freezing should spread locally and thaw slowly after leaving.
• Tap the passive ability name: a description only, with no equip toggle. Starting passives are already assigned.
• Water floats, Air glides, Stone takes the passage beneath the bridge and climbs the bank, and Fire evaporates water at a health cost.
• Check health, mana, fur, wind, wetting, jumps in both directions, rotation and return from background.

Include your device model, form, location and frame smoothness in feedback.
```
