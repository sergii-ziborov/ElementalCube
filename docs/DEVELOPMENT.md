# Разработка ElementalCube

SwiftUI + MetalKit/Metal, Box2D 3.1.1 и локальные XCTest. Общий игровой код используется на iPhone, iPad и Mac.

## Запуск на Mac

```sh
./scripts/run-mac.sh
```

Скрипт локально собирает `build/ElementalCube.app`, подписывает временной подписью и открывает приложение. Нужен установленный Xcode; внешние пакеты при сборке не скачиваются.

## iPhone / iPad

Откройте **ElementalCube.xcodeproj**, выберите схему **ElementalCube-iOS** и симулятор или своё устройство. Для физического устройства выберите свою Team в Signing & Capabilities. Поддерживаются портретная и обе горизонтальные ориентации; поворот отменяет незавершённый жест.

Проект уже сгенерирован. Если изменён `project.yml`, обновите его локально:

```sh
xcodegen generate
```

Сборка симулятора из терминала:

```sh
xcodebuild -project ElementalCube.xcodeproj -scheme ElementalCube-iOS \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios CODE_SIGNING_ALLOWED=NO build
```

## Проверки

Альфа для iPhone/iPad собирается и загружается вручную: [TestFlight](TESTFLIGHT.md). Политика конфиденциальности: [PRIVACY.md](PRIVACY.md).

```sh
swift test
```

Проверяются столкновения, запрет воздушного прыжка, плавучесть, выход из воды без льда, отверстие при замораживании вокруг погружённого куба, время таяния, вращение при качении, разница скольжения, жёсткость посадки, направления жеста, совпадение предпросмотра и исполненного импульса, воспроизводимость и прохождение карты реальными прыжками.

## Состав

- `Sources/ElementalCore` — физический мир, материалы, вода, события, прицеливание.
- `Sources/CPhysics` — узкая C-обёртка над Box2D.
- `Sources/ElementalCube` — общий Metal-рендер, геометрия, SwiftUI, адаптеры ввода.
- `Vendor/Box2D` — закреплённый исходный релиз 3.1.1; лицензия MIT.
- `Tests/ElementalCoreTests` — локальные проверки физики и управления.
- `project.yml` — описание iOS-проекта для XcodeGen.

`Shaders.metal.txt` намеренно копируется как текст и компилируется через Metal API при запуске: сборка не требует отдельно установленного Metal Toolchain.
