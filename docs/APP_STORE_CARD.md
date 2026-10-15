# ElementalCube — материалы карточки Apple

Альфа **0.1.0 (7)** для iPhone и iPad. Актуальное состояние загрузки и проверки: [TestFlight](TESTFLIGHT.md). [Нативные снимки](../Previews/gestures7).

Apple ID `6822921592` · Bundle ID `com.weavatrix.elementalcube` · версия 0.1.0 · Games / Puzzle / Adventure.

[Игра](https://github.com/sergii-ziborov/ElementalCube) · [Поддержка](https://github.com/sergii-ziborov/ElementalCube/issues) · [Конфиденциальность](https://github.com/sergii-ziborov/ElementalCube/blob/main/docs/PRIVACY.md)

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

### Описание

```text
Маленький куб. Большой мир.

Выберите одну из пяти стихий и исследуйте тихий берег. Льдинка сразу создаёт ледяную опору при касании воды и затем постепенно расширяет лёд; Капля плавает; Ветерок скользит над водой; Камушек тонет и находит подводные проходы; Огонёк сжигает горючее и испаряет воду, теряя здоровье.

Начальная пассивная способность уже назначена и работает автоматически. Нажатие на название открывает описание. Здоровье и мана всегда видны; выбирайте, где тратить силы.

Коснитесь карты для движения. Потяните самого куба в сторону полёта и отпустите: пунктир показывает дугу, а силу ограничивает изученный навык. Катитесь по траве, толкайте и опрокидывайте плавучий ящик, раскачивайте подвесной мост, скользите по льду и плывите к берегу. Доберитесь до флага, соберите двенадцать кристаллов или отправьтесь каменной формой за глубинной реликвией.

Кубик реагирует на ваши действия: сосредотачивается перед прыжком, радуется находкам и встряхивает мокрую шерсть. Пряди спереди и по бокам меняются от ветра, движения и намокания. Мягкая трава и твёрдый камень по-разному встречают его после полёта; поддерживаемые iPhone добавляют тактильный отклик.

Это ранняя альфа ElementalCube: карта в четыре раза шире и выше прежней, пять форм и личный инвентарь для проверки управления и физики. В личном инвентаре — отдельное дерево выбранного монстра, талисманы и материалы. Навыки меняют физику, предметы можно надевать и снимать; находки и прогресс сохраняются. Слияние, обучение и арены ещё не реализованы.

Игра работает без регистрации, рекламы и игрового сервера. Поддерживаются iPhone и iPad, портретная и горизонтальная ориентации. Настройки, выбранная форма сохраняются.
```

### Описание TestFlight

```text
ElementalCube 0.1.0 (7)

Без кнопок движения: касайтесь карты или ведите по ней пальцем. Потяните самого куба в сторону полёта — пунктир показывает дугу, длина жеста определяет силу до предела навыка.

Карта 112 × 52 м: высокие террасы, скальный спуск, пещера, двенадцать кристаллов. Личный инвентарь выбранного монстра: своё дерево, талисманы и материалы. Изучение и экипировка меняют физические параметры; прогресс сохраняется.

Лёд появляется сразу, затем утолщается от времени контакта и постепенно распространяется. Вода и лёд сохраняют массу; после прыжка куба и таяния старые импульсы не возвращаются.

Пять типов, физические ящик и мост, здоровье и мана, ветер и мокрая шерсть. Слияния и арены пока нет. Интерфейс на русском, без регистрации и сервера.
```

### What to Test — build 7

```text
Альфа 0.1.0 (7) — прямые жесты и личный инвентарь.

• Касайтесь карты слева/справа, ведите пальцем: куб двигается к точке без прыжка.
• Тяните именно куба в сторону полёта. Сравните слабый и длинный жест, обе стороны, пунктир и фактическую дугу. Маленький тап не должен прыгать.
• Поверните устройство, уйдите в фон: незавершённый жест должен отмениться.
• Оставьте Льдинку на воде: первая корка сразу, затем толще вниз и шире в стороны. Прыгните с неё, посмотрите на воду, дождитесь таяния.
• Откройте инвентарь кнопкой стихии. Изучите навык за очко, наденьте/снимите оберег, проверьте материалы после находки и перезапуска. У другого типа своё дерево и прогресс.
• Исследуйте западные высоты, восточный спуск и нижнюю пещеру; проверьте камеру. В мире 12 кристаллов и новый финиш.
• Проверьте пять типов, ящик и мост, выход из воды, здоровье, ману, намокание.

Укажите модель устройства, тип куба, место проблемы и плавность игры.
```

## English

### Подзаголовок

```text
Small cube. Big world.
```

### Промотекст

```text
Five elements, five personalities. Freeze water by touch, glide above it, explore the bottom, or evaporate a pond with fire in a playful physics sandbox.
```

### Ключевые слова

```text
cube,physics,platformer,ice,water,jump,puzzle,adventure,cozy
```

### Описание

```text
Small cube. Big world.

Choose one of five elements and explore a quiet shore. Ice immediately forms support on first water contact, then gradually spreads the freeze. Water floats. Air slides above the surface. Stone sinks into underwater passages. Fire burns fuel and evaporates water at a health cost.

Your starting passive is already assigned and works automatically. Tap its name to read the description. Health and mana are visible from the start.

Tap or drag on the map to move. Drag the cube itself toward the flight direction and release to jump along the dotted arc, up to its learned skill limit. Roll over grass, push and tip a floating crate, and load a suspended bridge, slide on ice, and swim back to shore. Reach the flag, collect twelve crystals, or take Stone through the passage to a deep relic.

Your cube has a personality: it focuses before a jump, celebrates discoveries, and shakes its wet fur. Strands on the front and sides react to wind, motion, and water. Soft grass and hard stone create different landings. Supported iPhones add tactile feedback.

This is an early ElementalCube alpha with a map four times wider and taller, five forms, and a personal monster inventory. Each monster has its own skill tree, equipment and materials. Learning and equipped charms change simulation parameters; discoveries and progress persist. Merging, training and arenas are not available yet.

No account, ads, or game server connection is required. Designed for iPhone and iPad in portrait and landscape. Settings and selected form persist locally.

The current in-game interface is in Russian.
```

### Описание TestFlight

```text
ElementalCube 0.1.0 (7)

Direct gestures: tap or drag on the map to move. Drag the cube itself toward the flight direction; the dotted arc previews the jump. A longer drag gives more power, limited by its learned skill.

A 112 × 52 m world with terraces, cliff shelves, a cavern and twelve crystals. Personal inventory: an individual skill tree, charms and materials. Learning and equipment affect real parameters; progress persists locally.

Ice forms an immediate thin skin and thickens with contact time. Cold spreads through the connected sheet. Freezing and thawing conserve represented mass without replaying old splash velocities.

Five types, a physical crate and bridge, health and mana, wind and wet fur. Merging and arenas are not available yet. Russian interface; no account or server required.
```

### What to Test — build 7

```text
Alpha 0.1.0 (7): direct gestures and personal inventory.

• Tap/drag left or right on the map: movement without jumping.
• Drag the cube itself toward flight. Compare short/long gestures, both directions and the dotted preview. Tiny taps should not jump.
• Rotate or background the app: unfinished gestures should cancel.
• Leave Ice on water: immediate skin, then thicker and wider ice. Jump off and observe water; wait for thawing.
• Open inventory from the element button. Learn a skill, equip/unequip a charm, collect materials and relaunch. Other types have independent trees and progress.
• Explore western heights, eastern shelves and the lower cavern. Check the camera, twelve crystals and new finish.
• Check all five types, the crate and bridge, water exits, health, mana and wetting.

Include device model, cube type, location and frame smoothness.
```
