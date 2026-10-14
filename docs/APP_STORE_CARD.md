# ElementalCube — материалы карточки Apple

Версия альфы: **0.1.0 (4)**. Одно приложение для iPhone и iPad. Карточка [App Store Connect](https://appstoreconnect.apple.com/apps/6822921592/testflight) заполнена на русском и английском, включая задания тестерам и 12 снимков экрана. Внутреннее тестирование запущено 15 октября 2026; [внешняя альфа](https://testflight.apple.com/join/snm99FQh) ожидает проверки Apple.

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


Иконка: [PNG 1024 × 1024](../Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png). Скриншоты текущей сборки: [альфа 4](../Previews/alpha4). [Архивные размеры Apple](../Previews/app-store) относятся к сборкам 2 и 3.


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

Выберите одну из пяти стихий и исследуйте тихий берег. Льдинка постепенно замораживает воду касанием; Капля плавает; Ветерок скользит над водой; Камушек тонет и находит подводные проходы; Огонёк сжигает горючее и испаряет воду, теряя здоровье.

Начальную пассивную способность нужно экипировать в слот. После этого она работает автоматически. Нажатие на слот открывает описание. Здоровье и мана всегда видны; выбирайте, где тратить силы.

Потяните и отпустите, чтобы прыгнуть по выбранной дуге. Катитесь по траве, толкайте деревянный ящик, скользите по льду и плывите к берегу. Доберитесь до флага, соберите три кристалла или отправьтесь каменной формой за глубинной реликвией.

Кубик реагирует на ваши действия: сосредотачивается перед прыжком, радуется находкам и встряхивает мокрую шерсть. Пряди спереди и по бокам меняются от ветра, движения и намокания. Мягкая трава и твёрдый камень по-разному встречают его после полёта; поддерживаемые iPhone добавляют тактильный отклик.

Это ранняя альфа ElementalCube: одна карта и пять форм для проверки управления и физики. Обучение, эволюция, арены и сохранение прохождения ещё не реализованы.

Игра работает без регистрации, рекламы и игрового сервера. Поддерживаются iPhone и iPad, портретная и горизонтальная ориентации. Настройки, выбранная форма и экипировка сохраняются.
```

### Описание TestFlight

```text
Добро пожаловать в альфу ElementalCube 0.1.0 (4)!

Пять форм меняют способ движения и взаимодействия с миром: лёд постепенно замораживает, вода плавает, воздух скользит, камень исследует дно, огонь сжигает и испаряет воду с потерей здоровья.

Выберите стихию кнопкой сверху. Нажмите на слот, прочитайте описание и экипируйте пассивную способность — повторные нажатия для применения не нужны. Здоровье и мана видны сразу. Смена формы начинает новую попытку.

Шерсть на всех гранях, включая переднюю, реагирует на ветер, движение и воду. В настройках можно изменить ветер, гравитацию и управление.

В альфе одна карта. Обучение, эволюция, арены и сохранение прохождения ещё не готовы. Особенно интересуют ощущения управления и производительность на физических iPhone и iPad.
```

### Что проверить — TestFlight

```text
Альфа 0.1.0 (4) — пять стихий и пассивные способности.

• Выберите каждую форму кнопкой сверху; смена начинает новую попытку.
• Нажмите слот или название способности. Откроется описание с переключателем экипировки. После включения способность работает автоматически.
• Проверьте здоровье и ману, истощение и возобновление способности после 20 маны.
• Лёд: двигайтесь вдоль воды. Она должна замерзать постепенно рядом с кубом, вверх и вниз. Выберитесь на берег; лёд не должен запечатывать героя.
• Вода: плывите и выходите по береговому склону. Прыжок в воде расходует 6 маны.
• Воздух: скользите без качения по суше и над водой.
• Камень: опуститесь на дно, пройдите под центральной опорой за реликвией и вернитесь по склону.
• Огонь: зажгите траву и ящик; проверьте обугленный след. В воде наблюдайте пар, падение уровня и потерю здоровья.
• Посмотрите на шерсть спереди, измените ветер, намочите и высушите куба.
• Сравните посадку на траву и камень. Поверните устройство и вернитесь из фона: управление не должно застревать.

В отзыве укажите модель устройства, форму, место проблемы и ощущение скорости/плавности игры.
```

## English (US)

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

### Описание App Store

```text
Small cube. Big world.

Choose one of five elements and explore a quiet shore. Ice gradually freezes nearby water by touch. Water floats. Air slides above the surface. Stone sinks into underwater passages. Fire burns fuel and evaporates water at a health cost.

Equip your starting passive ability in its slot, then let it work automatically. Tapping the slot opens its description. Health and mana are visible from the start.

Drag and release to jump along your chosen arc. Roll over grass, push a wooden crate, slide on ice, and swim back to shore. Reach the flag, collect three crystals, or take Stone through the passage to a deep relic.

Your cube has a personality: it focuses before a jump, celebrates discoveries, and shakes its wet fur. Strands on the front and sides react to wind, motion, and water. Soft grass and hard stone create different landings. Supported iPhones add tactile feedback.

This is an early ElementalCube alpha with one map and five forms. Training, evolution, arenas, and saved playthroughs are not available yet.

No account, ads, or game server connection is required. Designed for iPhone and iPad in portrait and landscape. Settings, selected form, and equipped passive persist locally.

The current in-game interface is in Russian.
```

### Описание TestFlight

```text
Welcome to ElementalCube alpha 0.1.0 (4)!

Five forms change movement and interaction: Ice gradually freezes, Water swims, Air slides, Stone explores the bottom, and Fire burns fuel and evaporates water at a health cost.

Choose an element at the top. Tap the ability slot, read its description, and equip the passive. It then works automatically. Health and mana are visible immediately. Switching forms starts a new attempt.

Fur on all faces, including the front, reacts to wind, movement, and water. Wind, gravity, and controls can be adjusted in Settings.

This alpha has one map. Training, evolution, arenas, and saved playthroughs are not ready. Please focus on controls and performance on physical iPhones and iPads.

The current in-game interface is in Russian.
```

### Что проверить — TestFlight

```text
Alpha 0.1.0 (4): five elements and passive abilities.

• Try every form using the top button. Switching resets the map.
• Tap the slot or ability name. Read the description and equip the passive. It should then work automatically.
• Watch health and mana, exhaustion, and ability recovery at 20 mana.
• Ice: move near water and watch freezing grow locally up and down. Leave the water without getting sealed inside ice.
• Water: swim and leave along the bank. A water stroke costs 6 mana.
• Air: slide without rolling on land and above water.
• Stone: sink, take the passage beneath the central support, collect the relic, and climb back out.
• Fire: ignite grass and the crate, leaving char. In water, watch steam, the receding level, and health loss.
• Inspect front fur, change wind, and wet/dry the cube.
• Compare soft and hard landings, rotate the device, and return from background. Controls should not stay pressed.

Please include your device model, form, location, and impressions of speed and smoothness in feedback.
```

Контакт для обратной связи TestFlight: `sergii.ziborov@gmail.com`. Игра не требует учётной записи или демо-пароля. Контактный телефон для Apple Beta App Review заполняется отдельно владельцем аккаунта.
