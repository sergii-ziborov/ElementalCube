# ElementalCube — тексты карточки 0.1.0 (16)

Ручной выпуск; фактический статус в [TESTFLIGHT.md](TESTFLIGHT.md). Интерфейс игры русский.

## ru

### subtitle

Маленький куб. Большой мир.

### promotionalText

Вода, лёд и кирпичная кладка: пробей подводную стенку Камушком, открой путь и продолжи путешествие по семи этапам.

### description

ElementalCube — маленький друг из большой стихии. Ранняя нативная альфа для iPhone и iPad с русским интерфейсом.

Выбери первого кубика или доверься случайности. Льдинка скользит и постепенно замораживает воду; гладкая Капля сжимается перед скачком, плавает и проходит низкие щели; Ветерок летит над поверхностью; тяжёлый Камушек катится, тонет и выбивает кирпичи; Огонёк медленно перетекает, обугливает дерево и траву, кипятит воду за здоровье.

Свайп вверх — бесплатный обычный прыжок. Нажми или проведи по карте, чтобы двигаться; погладь кубика, чтобы увидеть реакцию. Прицельный и двойной прыжки открываются через изучение. Врождённая пассивка действует автоматически и не тратит ману.

Семь этапов соединены двумя ветками путешествия: берег, ледяные высоты либо тёплый сад, лес либо гроты, ветреный перевал и древний маяк. Финиш показывает время, находки и награды, открывает продолжение. Монеты, кристаллы и талисманы различаются; уже найденное не выдаётся повторно. Скоростные медали доступны при стандартной физике.

В альфе 16 лёд учитывает реальные формы ящика, досок и обломков. Вода проверяет путь частиц через тонкие преграды. В подводном проходе гротов появилась кирпичная кладка со связями: удар выбивает кирпич, части без опоры падают, а вода занимает освободившееся место. Обломки сохраняются за кадром.

Личное дерево показывает изученные приёмы и реальные эффекты улучшений. В лаборатории можно вырастить и объединить друзей: форма результата известна заранее, от каждого источника выбираются ровно две из четырёх карточек, донор остаётся. Потери и фиксаторы показаны до подтверждения.

Прогресс хранится локально. Нет входа, рекламы и покупок за реальные деньги. Это незавершённая физическая песочница: модель воды приближённая, нет свободных кусков льда, конденсации, полного каталога заклинаний, локальных травм, обучаемого бота или серверной арены. Карта путешествия соединяет отдельные уровни.

### betaDescription

ElementalCube — маленький друг из большой стихии. Ранняя нативная альфа для iPhone и iPad с русским интерфейсом.

Выбери первого кубика или доверься случайности. Льдинка скользит и постепенно замораживает воду; гладкая Капля сжимается перед скачком, плавает и проходит низкие щели; Ветерок летит над поверхностью; тяжёлый Камушек катится, тонет и выбивает кирпичи; Огонёк медленно перетекает, обугливает дерево и траву, кипятит воду за здоровье.

Свайп вверх — бесплатный обычный прыжок. Нажми или проведи по карте, чтобы двигаться; погладь кубика, чтобы увидеть реакцию. Прицельный и двойной прыжки открываются через изучение. Врождённая пассивка действует автоматически и не тратит ману.

Семь этапов соединены двумя ветками путешествия: берег, ледяные высоты либо тёплый сад, лес либо гроты, ветреный перевал и древний маяк. Финиш показывает время, находки и награды, открывает продолжение. Монеты, кристаллы и талисманы различаются; уже найденное не выдаётся повторно. Скоростные медали доступны при стандартной физике.

В альфе 16 лёд учитывает реальные формы ящика, досок и обломков. Вода проверяет путь частиц через тонкие преграды. В подводном проходе гротов появилась кирпичная кладка со связями: удар выбивает кирпич, части без опоры падают, а вода занимает освободившееся место. Обломки сохраняются за кадром.

Личное дерево показывает изученные приёмы и реальные эффекты улучшений. В лаборатории можно вырастить и объединить друзей: форма результата известна заранее, от каждого источника выбираются ровно две из четырёх карточек, донор остаётся. Потери и фиксаторы показаны до подтверждения.

Прогресс хранится локально. Нет входа, рекламы и покупок за реальные деньги. Это незавершённая физическая песочница: модель воды приближённая, нет свободных кусков льда, конденсации, полного каталога заклинаний, локальных травм, обучаемого бота или серверной арены. Карта путешествия соединяет отдельные уровни.

### whatToTest

Альфа 16: вода, лёд и кирпичная кладка.

• В гротах рядом с глубинной реликвией стоит подводная стенка из девяти связанных кирпичей. Камушек сильным ударом выбивает отдельный кирпич; части без связи с основанием падают. Слабые касания стенку не рушат. Над ней остаётся путь для плавающих форм.
• Кирпич сохраняет ID и массу, становится настоящим подвижным телом и тонет. Вода занимает пробоину. Крупные обломки не исчезают за камерой. Начальная вода исключает занятое стенкой место.
• Лёд учитывает повёрнутые ящики, тонкие доски, обломки и края берега. Под доской больше не создаётся условная пустота размером с кубик. Прыжок с ледяной поверхности и оттаивание проверены отдельно.
• Движение воды и брызг проверяется на всём пути через тонкую преграду; испытание закрытого/открытого шлюза доступно в тестах ядра, не в игровом меню.
• Длинный свайп вверх на большом экране тоже прыгает: прежнего ограничения в 0,65 секунды нет. Удержание кубика остаётся лаской/прицелом.
• Если не хватает места для всех обломков или коллайдера льда, исходный предмет/жидкость сохраняются.

Сохраняются семь этапов, развилки, финиш/монеты/медали, разные движения стихий, иллюстрированные талисманы и правила наследования. Свайп вверх — обычный прыжок; карта — движение; кубик — ласка. Прицел и двойной прыжок изучаются, пассивки бесплатны.

Модель воды по-прежнему приближённая. Свободные ледяные куски, конденсация, общий баланс топлива/золы, полный каталог заклинаний, локальные травмы, обучаемый бот и серверная арена ещё впереди. Сообщи форму, участок и действие при сбое; в игре должна быть надпись АЛЬФА · 16.

## en-US

### subtitle

Small cube. Big world.

### promotionalText

Water, ice and bonded masonry: knock bricks from a submerged wall with Stone and continue a branching journey across seven stages.

### description

ElementalCube is a tiny friend made of a big element. An early native alpha for iPhone and iPad. The game interface is in Russian.

Choose your first cube or generate a random friend. Ice slides and progressively freezes water. Smooth Water squashes before hopping, swims and fits low passages. Air flies above surfaces. Heavy Stone rolls, sinks and knocks bricks loose. Fire flows more slowly, chars contacted wood and grass, and boils water at a health cost.

Swipe upward for a free basic jump. Tap or drag the map to move; stroke your cube for a reaction. Aimed and double jumps require learning. The innate passive works automatically without spending mana.

Seven stages form two journey branches: the shore, icy heights or warm garden, woodland or grottos, a windy pass and an ancient lighthouse. Finish shows time, finds and rewards, then opens the next area. Coins, crystals and illustrated talismans are distinct. Repeated finds do not duplicate rewards. Speed medals require standard physics.

Alpha 16 makes ice growth respect actual crates, planks and fragments. Water checks particle travel against thin obstacles. Bonded brick masonry stands in an optional submerged grotto passage: impacts release bricks, unsupported components fall and water fills the space. Fragments remain beyond the camera.

A personal tree shows learned techniques and their numeric effects. Grow and merge friends in the laboratory: the resulting form is known, exactly two of four cards are selected from each source, and the donor stays. Losses and pins are shown before confirmation.

Progress is local. No login, ads or real-money purchases. This remains an unfinished physics playground: water is approximate; free ice fragments, condensation, the full spell catalog, local injuries, trained bots and server arenas are not implemented. The journey map connects separate levels.

### betaDescription

ElementalCube is a tiny friend made of a big element. An early native alpha for iPhone and iPad. The game interface is in Russian.

Choose your first cube or generate a random friend. Ice slides and progressively freezes water. Smooth Water squashes before hopping, swims and fits low passages. Air flies above surfaces. Heavy Stone rolls, sinks and knocks bricks loose. Fire flows more slowly, chars contacted wood and grass, and boils water at a health cost.

Swipe upward for a free basic jump. Tap or drag the map to move; stroke your cube for a reaction. Aimed and double jumps require learning. The innate passive works automatically without spending mana.

Seven stages form two journey branches: the shore, icy heights or warm garden, woodland or grottos, a windy pass and an ancient lighthouse. Finish shows time, finds and rewards, then opens the next area. Coins, crystals and illustrated talismans are distinct. Repeated finds do not duplicate rewards. Speed medals require standard physics.

Alpha 16 makes ice growth respect actual crates, planks and fragments. Water checks particle travel against thin obstacles. Bonded brick masonry stands in an optional submerged grotto passage: impacts release bricks, unsupported components fall and water fills the space. Fragments remain beyond the camera.

A personal tree shows learned techniques and their numeric effects. Grow and merge friends in the laboratory: the resulting form is known, exactly two of four cards are selected from each source, and the donor stays. Losses and pins are shown before confirmation.

Progress is local. No login, ads or real-money purchases. This remains an unfinished physics playground: water is approximate; free ice fragments, condensation, the full spell catalog, local injuries, trained bots and server arenas are not implemented. The journey map connects separate levels.

### whatToTest

Alpha 16: water, ice and bonded masonry.

• An optional submerged grotto wall beside the deep relic contains nine bonded bricks. A strong Stone impact knocks a brick loose. Components disconnected from the foundation fall; weak touches do not collapse the wall. Swimming forms can pass above it.
• Released bricks retain ID and mass, become dynamic and sink. Water fills the opening. Large fragments remain beyond the camera. Initial water excludes the masonry volume.
• Ice growth respects rotated crates, thin planks, fragments and bank edges instead of reserving a cube-sized void around every body centre. Jumping from ice and thawing are checked separately.
• Water and spray use continuous path collision against thin obstacles. A closed/open sluice experiment is in core tests, not a gameplay control.
• Long upward strokes on a large screen still jump: the old 0.65-second timeout is removed. Stationary cube holds retain pet/aim semantics.
• If the physics pool cannot fit every fragment or ice collider, the original object/liquid is retained.

Seven stages, branches, finish rewards, coins, speed medals, distinct gaits, illustrated talismans and inheritance rules remain. Swipe up for a basic jump, tap/drag the map to move, stroke the cube for affection. Aimed and double jumps require learning. Passives are free.

Water remains approximate. Free ice fragments, condensation, a closed fuel/ash ledger, the full spell catalog, local injuries, trained bots and server arenas remain unfinished. Please report form, area and action for failures. The in-game badge should read alpha 16.
