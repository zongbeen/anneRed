# anneRed Apple Design 정비 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** anneRed D-day 앱을 Apple 유체 인터페이스 원칙에 맞게 정비한다 — 안정적 식별자, 애니메이션 있는 리스트, press 피드백·햅틱, Dynamic Type, 다크모드 수정, 한국어 문구 통일.

**Architecture:** UIKit + 스토리보드를 유지한다. 리스트는 `UITableViewDiffableDataSource`로 전환하고, Core Data에 `UUID` 식별자를 추가해 애니메이션 diff의 토대를 만든다. 셀은 xib를 버리고 코드로 재작성해 자기 크기 조정을 성립시킨다. iOS 26 시스템 크롬(유리 재질)은 직접 만들지 않고 그대로 받는다.

**Tech Stack:** Swift 5, UIKit, Core Data (경량 마이그레이션), WidgetKit (계약 불변), Xcode 26 / iOS 26 배포 타깃.

## Global Constraints

- 배포 타깃 iOS 26.0 — `if #available(iOS 15.0, *)` 류 가드는 죽은 코드
- 시뮬레이터: iPhone 17 Pro (`EFDB940D-9586-4164-A877-B9B62A647728`)
- 빌드/검증 게이트 (매 태스크 종료 시): 아래 명령이 `BUILD SUCCEEDED`
  ```bash
  cd /Users/zongbeen/Desktop/anneRed/anneRed && xcodebuild -project anneRed.xcodeproj -scheme anneRed -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
  ```
- 스프링 기본값: 일반 전환 `dampingRatio 1.0`(bounce 0) / `duration 0.4`; 제스처 운동량이 실린 전환만 bounce 0.2; press 피드백 `dampingRatio 1.0` / `duration 0.25`
- 햅틱은 4곳으로 제한: 고정/해제 `.light` impact, 삭제 `.rigid` impact, 저장 성공 `.success`, 고정 한도 `.warning`. 전부 사전 `prepare()`
- `monospacedDigitSystemFont` + Dynamic Type(`UIFontMetrics`, `adjustsFontForContentSizeCategory`)를 D-day 숫자에 적용
- Reduced Motion 시 스프링·오버슈트를 짧은 크로스페이드로 대체 (햅틱·색은 유지)
- UI 문구는 한국어. 매핑: Record→기록, Add List→새 D-Day/편집, Edit/Done→편집/완료, Cancel/Save→취소/저장, Pinned/Other→고정/나머지, Title→제목, Calculate→일수, "Item 1"(탭바)→기록
- 커밋 메시지 말미: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- 커밋은 git author `zongbeen <jongbeen825@gmail.com>` 사용

---

## File Structure

**신규**
- `anneRed/DdayCalculator.swift` — D-day 계산 순수 함수 (현재 3곳에 중복된 로직 통합)
- `anneRed/DdayCell.swift` — 코드 기반 셀 (`TableViewCell.xib` + `TableViewCell.swift` 대체)
- `anneRed/Haptics.swift` — 햅틱 헬퍼 (준비/발사 캡슐화)
- `anneRed/DatePickerCells.swift` — DatePicker 화면의 재사용 셀 2종
- `anneRed/MotionPreference.swift` — Reduced Motion 헬퍼 + 스프링 파라미터 상수

**수정**
- `anneRed.xcdatamodeld/anneRed.xcdatamodel/contents` — `id: UUID` 속성
- `DdayData+CoreDataProperties.swift` — `id` 프로퍼티
- `AppDelegate.swift` — UUID 백필 마이그레이션
- `DdayDataManager.swift` — `id` 부여, `removeData(id:)`, 문구
- `DdayViewController.swift` — diffable, 헤더 다크모드, press/편집 모션, 문구
- `DatePickerViewController.swift` — 델리게이트, 셀 재사용, 강제 언래핑 정리, 문구, 오타
- `TableViewCell.swift` — 삭제
- `TableViewCell.xib` — 삭제
- `ViewController.swift` — 삭제
- `Model.swift` — 삭제
- `Base.lproj/Main.storyboard` — 탭바 "Item 1" 제목, 셀 프로토타입 정리

---

## Task 1: D-day 계산 로직 통합

D-day 문자열 계산이 `DdayViewController.calculateDday`, `DatePickerViewController.updateDdayLabel`, `TableViewCell.calculateDday` 세 곳에 복제돼 있다. 순수 함수 하나로 통합해 이후 태스크가 공유한다. (DRY, 이후 셀·마이그레이션 태스크의 선행)

**Files:**
- Create: `anneRed/DdayCalculator.swift`

**Interfaces:**
- Produces:
  - `enum DdayCalculator { static func days(from now: Date, to target: Date) -> Int }`
  - `static func text(daysLeft: Int) -> String` — `>0`→`"D-\(n)"`, `0`→`"D-Day"`, `<0`→`"D+\(abs)"`
  - `static func text(from now: Date, to target: Date) -> String`

- [ ] **Step 1: 파일 생성**

`anneRed/DdayCalculator.swift`:

```swift
import Foundation

enum DdayCalculator {
    /// 시각을 무시하고 달력상의 날짜 차이(일)를 반환한다.
    static func days(from now: Date, to target: Date) -> Int {
        let cal = Calendar.current
        let a = cal.dateComponents([.year, .month, .day], from: now)
        let b = cal.dateComponents([.year, .month, .day], from: target)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func text(daysLeft: Int) -> String {
        if daysLeft > 0 { return "D-\(daysLeft)" }
        if daysLeft == 0 { return "D-Day" }
        return "D+\(abs(daysLeft))"
    }

    static func text(from now: Date, to target: Date) -> String {
        text(daysLeft: days(from: now, to: target))
    }
}
```

- [ ] **Step 2: 프로젝트에 파일 추가 확인**

새 `.swift` 파일은 Xcode 프로젝트의 `anneRed` 타깃에 등록돼야 컴파일된다. `project.pbxproj`에 파일 참조가 없으면 빌드에서 제외되므로, 빌드가 이 파일의 심볼을 인식하는지 다음 태스크에서 사용해 확인한다. (이 태스크는 아직 호출부가 없어 빌드만으로는 등록 여부를 알 수 없다 — 등록은 Xcode가 자동 처리하지 않으므로 `project.pbxproj`에 수동 추가하거나, 편집 중 Xcode가 열려 있으면 자동 추가된다. CLI 환경에서는 `project.pbxproj`에 `PBXFileReference` + `PBXBuildFile` + 그룹/소스 빌드 단계 엔트리를 추가한다.)

> 실행 주의: 이 프로젝트는 CLI로 빌드하므로, 신규 파일마다 `project.pbxproj`에 세 엔트리(파일 참조, 빌드 파일, 소스 컴파일 단계 멤버십)를 추가해야 한다. 각 신규 파일 태스크의 마지막에 이 등록을 포함한다.

- [ ] **Step 3: project.pbxproj에 DdayCalculator.swift 등록**

`anneRed.xcodeproj/project.pbxproj`에서 기존 `Model.swift`의 3개 엔트리 형식을 찾아 동일 패턴으로 `DdayCalculator.swift`를 추가한다 (`PBXBuildFile`, `PBXFileReference`, `anneRed` 그룹의 children, `PBXSourcesBuildPhase`의 files). UUID는 24자리 hex를 새로 생성해 중복되지 않게 한다.

- [ ] **Step 4: 빌드**

Run: Global Constraints의 빌드 명령
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: 커밋**

```bash
git add anneRed/DdayCalculator.swift anneRed.xcodeproj/project.pbxproj
git commit -m "refactor: D-day 계산 로직을 DdayCalculator로 통합

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Core Data에 UUID 식별자 추가 + 백필 마이그레이션

신원을 `selectedDate`에서 `UUID`로 옮긴다. 같은 날짜 항목이 구분되지 않던 데이터 결함을 고치고, diffable data source의 안정적 식별자를 확보한다. **데이터 위험이 있는 유일한 태스크** — 기존 데이터가 있는 시뮬레이터에서 백필을 확인한다.

**Files:**
- Modify: `anneRed/anneRed.xcdatamodeld/anneRed.xcdatamodel/contents`
- Modify: `anneRed/DdayData+CoreDataProperties.swift`
- Modify: `anneRed/AppDelegate.swift:16-21`
- Modify: `anneRed/DdayDataManager.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `DdayData.id: UUID?` (Core Data 속성)
  - `DdayDataManager.saveData(...)` 가 생성 시 `id = UUID()` 부여 (시그니처 불변)
  - `DdayDataManager.removeData(id: UUID, completion: @escaping () -> Void)` — 시그니처 변경 (기존 `removeData(deleteTarget:completion:)` 대체)
  - `AppDelegate.backfillMissingIDs()` — `id == nil` 레코드에 UUID 부여

- [ ] **Step 1: 모델에 id 속성 추가**

`anneRed.xcdatamodeld/anneRed.xcdatamodel/contents`의 `DdayData` 엔티티에 속성 추가 (optional — 경량 마이그레이션 성립):

```xml
    <entity name="DdayData" representedClassName="DdayData" syncable="YES">
        <attribute name="dday" optional="YES" attributeType="String"/>
        <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="selectedDate" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="title" optional="YES" attributeType="String"/>
    </entity>
```

- [ ] **Step 2: 프로퍼티 추가**

`DdayData+CoreDataProperties.swift`의 `@NSManaged` 목록에 추가:

```swift
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var dday: String?
    @NSManaged public var selectedDate: Date?
```

- [ ] **Step 3: saveData가 id를 부여하도록 수정**

`DdayDataManager.saveData`의 저장 블록에서 `data.selectedDate = selectedDate` 다음 줄에 추가:

```swift
        data.id = UUID()
        data.dday = dday
        data.title = title
        data.selectedDate = selectedDate
        if data.value(forKey: "id") == nil { data.id = UUID() }
```

실제로는 한 줄이면 된다 — `data.id = UUID()`를 세팅 블록에 넣는다. (위 중복 방지 라인은 불필요하므로 아래 최종형만 반영)

최종형:
```swift
        data.id = UUID()
        data.dday = dday
        data.title = title
        data.selectedDate = selectedDate
```

- [ ] **Step 4: removeData를 id 기준으로 교체**

`DdayDataManager.removeData` 전체를 교체:

```swift
    func removeData(id: UUID, completion: @escaping () -> Void) {
        guard let context = context else { completion(); return }
        let request = NSFetchRequest<NSManagedObject>(entityName: "DdayData")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            let fetched = try context.fetch(request) as? [DdayData] ?? []
            guard let data = fetched.first else { completion(); return }
            context.delete(data)
            try context.save()
            completion()
        } catch {
            completion()
        }
    }
```

- [ ] **Step 5: 백필 마이그레이션 추가**

`AppDelegate.application(_:didFinishLaunchingWithOptions:)`를 수정:

```swift
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let ddayDataManager = DdayDataManager.shared
        ddayDataManager.setup(context: persistentContainer.viewContext)
        backfillMissingIDs()
        return true
    }

    private func backfillMissingIDs() {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<DdayData>(entityName: "DdayData")
        request.predicate = NSPredicate(format: "id == nil")
        do {
            let missing = try context.fetch(request)
            guard !missing.isEmpty else { return }
            missing.forEach { $0.id = UUID() }
            try context.save()
        } catch {
            // 백필 실패는 치명적이지 않다 — 다음 실행에서 재시도된다
        }
    }
```

- [ ] **Step 6: removeData 호출부 임시 정리**

`DdayViewController.tableView(_:commit:forRowAt:)`의 `manager.removeData(deleteTarget: target)` 호출이 컴파일되지 않는다. Task 5에서 diffable로 재작성하지만, 지금 빌드를 통과시키기 위해 최소 수정:

```swift
            guard let id = target.id else { return }
            manager.removeData(id: id) {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
```

- [ ] **Step 7: 빌드**

Run: 빌드 명령
Expected: `BUILD SUCCEEDED`

- [ ] **Step 8: 시뮬레이터 검증 — 백필**

시뮬레이터에 기존 데이터가 있다면 앱을 실행해 크래시 없이 뜨는지, 항목이 그대로 보이는지 확인한다. 새 D-day를 같은 날짜로 2개 만든 뒤, 다음 태스크(삭제)를 위해 남겨둔다.

Run: `mcp__Claude_Code_iOS_Simulator__control` (build→launch→screenshot)
Expected: 앱 실행, 기존 항목 표시

- [ ] **Step 9: 커밋**

```bash
git add anneRed/anneRed.xcdatamodeld anneRed/DdayData+CoreDataProperties.swift anneRed/AppDelegate.swift anneRed/DdayDataManager.swift anneRed/DdayViewController.swift
git commit -m "feat: Core Data에 UUID 식별자 추가 및 백필 마이그레이션

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: 고정 목록을 UUID 기준으로 전환

고정 목록 저장을 ISO 날짜 문자열에서 UUID 문자열로 옮긴다. `updateStoredPinnedDate` 보정 코드를 제거한다.

**Files:**
- Modify: `anneRed/DdayViewController.swift` (`loadPinnedDates`, `savePinnedDates`, `reloadAllData`, `updateStoredPinnedDate` 제거, 키 상수)

**Interfaces:**
- Consumes: `DdayData.id: UUID?`
- Produces:
  - `pinnedIDsKey = "pinnedIDs"` 저장 키 (App Group)
  - `loadPinnedIDs() -> [UUID]`
  - `savePinnedIDs()` — `pinnedData`의 id를 문자열로 저장 + `saveWidgetData()`
  - 최초 1회 `pinnedDates`(ISO 날짜) → `pinnedIDs`(UUID) 변환

- [ ] **Step 1: 키 상수 교체**

`private let pinnedDatesKey = "pinnedDates"` → `private let pinnedIDsKey = "pinnedIDs"` 추가 (기존 키는 변환용으로 잠시 유지: `private let legacyPinnedDatesKey = "pinnedDates"`).

- [ ] **Step 2: loadPinnedIDs 작성 (레거시 변환 포함)**

`loadPinnedDates`를 대체:

```swift
    private func loadPinnedIDs() -> [UUID] {
        let shared = DdayViewController.sharedDefaults

        // UserDefaults.standard → App Group 1회 이관 (기존 마이그레이션 유지)
        if let migrated = UserDefaults.standard.stringArray(forKey: legacyPinnedDatesKey) {
            shared.set(migrated, forKey: legacyPinnedDatesKey)
            UserDefaults.standard.removeObject(forKey: legacyPinnedDatesKey)
        }

        // 이미 UUID 배열이 있으면 그대로
        if let ids = shared.stringArray(forKey: pinnedIDsKey) {
            return ids.compactMap { UUID(uuidString: $0) }
        }

        // 레거시 ISO 날짜 배열 → UUID 1회 변환
        guard let legacy = shared.stringArray(forKey: legacyPinnedDatesKey) else { return [] }
        let formatter = ISO8601DateFormatter()
        let dates = legacy.compactMap { formatter.date(from: $0) }
        let all = manager.getSavedData()
        let ids: [UUID] = dates.compactMap { date in
            all.first { Calendar.current.isDate($0.selectedDate ?? .distantPast, inSameDayAs: date) }?.id
        }
        shared.set(ids.map { $0.uuidString }, forKey: pinnedIDsKey)
        shared.removeObject(forKey: legacyPinnedDatesKey)
        return ids
    }
```

- [ ] **Step 3: savePinnedIDs 작성**

`savePinnedDates`를 대체:

```swift
    private func savePinnedIDs() {
        let ids = pinnedData.compactMap { $0.id?.uuidString }
        DdayViewController.sharedDefaults.set(ids, forKey: pinnedIDsKey)
        saveWidgetData()
    }
```

- [ ] **Step 4: reloadAllData를 UUID 기준으로 수정**

`reloadAllData`의 pinned 계산부를 교체:

```swift
    func reloadAllData() {
        let all = manager.getSavedData()
        let pinnedIDs = loadPinnedIDs()

        pinnedData = pinnedIDs.compactMap { id in all.first { $0.id == id } }
        let pinnedSet = Set(pinnedData.compactMap { $0.id })
        unpinnedData = all.filter { $0.id.map { !pinnedSet.contains($0) } ?? true }
        saveWidgetData()
        tableView.reloadData()   // Task 5에서 apply(snapshot)으로 교체
    }
```

- [ ] **Step 5: updateStoredPinnedDate 및 savePinnedDates 호출부 정리**

`updateStoredPinnedDate(from:to:)` 메서드 전체 삭제. `savePinnedDates()` 호출 두 곳(commit 삭제, 스와이프 액션)을 `savePinnedIDs()`로 교체. `DatePickerViewController` 쪽 `updateStoredPinnedDate` 호출은 Task 6에서 정리하므로, 지금은 컴파일 통과를 위해 해당 호출부를 잠시 주석 없이 삭제한다 (Task 6에서 델리게이트로 대체).

`DatePickerViewController.dismissAndReload`에서 다음 블록 삭제:
```swift
        if let ddayVC = ddayVC, let originalDate = originalDate, let newDate = selectedDate {
            ddayVC.updateStoredPinnedDate(from: originalDate, to: newDate)
        }
```

- [ ] **Step 6: 빌드**

Run: 빌드 명령
Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: 시뮬레이터 검증 — 같은 날짜 독립성**

Task 2에서 만든 같은 날짜 2개 항목 중 하나만 고정 → 다른 하나는 고정되지 않는지, 하나만 삭제 → 나머지가 남는지 확인.

- [ ] **Step 8: 커밋**

```bash
git add anneRed/DdayViewController.swift anneRed/DatePickerViewController.swift
git commit -m "feat: 고정 목록을 UUID 기준으로 전환하고 날짜 보정 코드 제거

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: 햅틱·모션 헬퍼

이후 태스크가 쓸 햅틱과 스프링/Reduced Motion 상수를 만든다.

**Files:**
- Create: `anneRed/Haptics.swift`
- Create: `anneRed/MotionPreference.swift`
- Modify: `anneRed.xcodeproj/project.pbxproj` (두 파일 등록)

**Interfaces:**
- Produces:
  - `enum Haptics`: `static func pinToggle()`, `delete()`, `saveSuccess()`, `limitWarning()`, `prepareImpact()`, `prepareNotification()`
  - `enum Motion`: `static var reduce: Bool`; `static func spring(bounce: CGFloat, duration: TimeInterval) -> UIViewPropertyAnimator`; 상수 `standardDuration = 0.4`, `pressDuration = 0.25`, `reduceCrossfade = 0.2`

- [ ] **Step 1: Haptics.swift 생성**

```swift
import UIKit

enum Haptics {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepareImpact() { impactLight.prepare() }
    static func prepareNotification() { notification.prepare() }

    static func pinToggle() { impactLight.impactOccurred() }
    static func delete() { impactRigid.impactOccurred() }
    static func saveSuccess() { notification.notificationOccurred(.success) }
    static func limitWarning() { notification.notificationOccurred(.warning) }
}
```

- [ ] **Step 2: MotionPreference.swift 생성**

```swift
import UIKit

enum Motion {
    static let standardDuration: TimeInterval = 0.4
    static let pressDuration: TimeInterval = 0.25
    static let editDuration: TimeInterval = 0.3
    static let reduceCrossfade: TimeInterval = 0.2

    static var reduce: Bool { UIAccessibility.isReduceMotionEnabled }

    /// bounce 0 = critically damped. bounce>0 = 약간의 오버슈트.
    static func spring(bounce: CGFloat, duration: TimeInterval) -> UIViewPropertyAnimator {
        // dampingRatio = 1 - bounce (근사). bounce 0 → 1.0, bounce 0.2 → 0.8
        let damping = max(0.1, 1.0 - bounce)
        let params = UISpringTimingParameters(dampingRatio: damping)
        return UIViewPropertyAnimator(duration: duration, timingParameters: params)
    }
}
```

- [ ] **Step 3: project.pbxproj에 두 파일 등록**

Task 1 Step 3과 동일한 방식으로 `Haptics.swift`, `MotionPreference.swift`를 세 엔트리씩 추가.

- [ ] **Step 4: 빌드**

Run: 빌드 명령
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: 커밋**

```bash
git add anneRed/Haptics.swift anneRed/MotionPreference.swift anneRed.xcodeproj/project.pbxproj
git commit -m "feat: 햅틱 및 모션 프리퍼런스 헬퍼 추가

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: 셀 코드 재작성 + 리스트 diffable 전환 + press/편집 모션

xib를 버리고 코드 셀을 만들면서 diffable data source, press 피드백, 편집 모션, 햅틱, 다크모드 헤더를 한 번에 세운다. 이 태스크의 산출물이 리스트의 체감을 결정한다.

**Files:**
- Create: `anneRed/DdayCell.swift`
- Delete: `anneRed/TableViewCell.swift`, `anneRed/TableViewCell.xib`
- Modify: `anneRed/DdayViewController.swift` (전반)
- Modify: `anneRed/Base.lproj/Main.storyboard` (셀 프로토타입 참조 제거 시 필요분)
- Modify: `anneRed.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `DdayCalculator`, `Haptics`, `Motion`, `DdayData.id`
- Produces:
  - `final class DdayCell: UITableViewCell` — `reuseID = "DdayCell"`, `func configure(with data: DdayData)`
  - `UITableViewDiffableDataSource<Section, UUID>` 기반 리스트
  - `applySnapshot(animated: Bool)`

- [ ] **Step 1: DdayCell.swift 생성**

```swift
import UIKit

final class DdayCell: UITableViewCell {
    static let reuseID = "DdayCell"

    private let ddayLabel = UILabel()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let stack = UIStackView()
    private var pressAnimator: UIViewPropertyAnimator?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // D-day: 큰 숫자 — monospaced digit + largeTitle 스케일 + 네거티브 트래킹
        let ddayBase = UIFont.monospacedDigitSystemFont(ofSize: 34, weight: .light)
        ddayLabel.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: ddayBase)
        ddayLabel.adjustsFontForContentSizeCategory = true

        titleLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label

        dateLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .regular))
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, dateLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(UIView())   // spacer
        stack.addArrangedSubview(ddayLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let m = UIFontMetrics(forTextStyle: .body)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: m.scaledValue(for: 14)),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -m.scaledValue(for: 14)),
        ])

        isAccessibilityElement = true
    }

    func configure(with data: DdayData) {
        guard let date = data.selectedDate else { return }
        let daysLeft = DdayCalculator.days(from: Date(), to: date)
        let ddayText = DdayCalculator.text(daysLeft: daysLeft)

        // 큰 숫자에 네거티브 트래킹
        ddayLabel.attributedText = NSAttributedString(
            string: ddayText,
            attributes: [.kern: -0.6]
        )

        titleLabel.text = data.title
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        dateLabel.text = df.string(from: date)

        // 편집 모드에서는 D-day 숨김
        ddayLabel.alpha = isEditing ? 0 : 1

        accessibilityLabel = "\(dateLabel.text ?? ""), \(ddayText), \(data.title ?? "")"
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        let target: CGFloat = editing ? 0 : 1
        if Motion.reduce || !animated {
            ddayLabel.alpha = target
            return
        }
        let anim = Motion.spring(bounce: 0, duration: Motion.editDuration)
        anim.addAnimations { self.ddayLabel.alpha = target }
        anim.startAnimation()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        pressAnimator?.stopAnimation(true)
        let scale: CGFloat = highlighted ? 0.97 : 1.0
        let bg: UIColor = highlighted ? .secondarySystemBackground : .clear
        if Motion.reduce {
            contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
            backgroundColor = bg
            return
        }
        let anim = Motion.spring(bounce: 0, duration: Motion.pressDuration)
        anim.addAnimations {
            self.contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.backgroundColor = bg
        }
        anim.startAnimation()
        pressAnimator = anim
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.transform = .identity
        backgroundColor = .clear
        ddayLabel.alpha = isEditing ? 0 : 1
    }
}
```

- [ ] **Step 2: TableViewCell.swift / .xib 삭제 및 pbxproj에서 참조 제거**

`git rm anneRed/TableViewCell.swift anneRed/TableViewCell.xib` 후 `project.pbxproj`에서 두 파일의 `PBXBuildFile`/`PBXFileReference`/그룹/빌드 단계 엔트리 제거. `DdayCell.swift` 등록 추가.

- [ ] **Step 3: DdayViewController에 diffable data source 도입**

`setupTableView`에서 nib 등록을 코드 셀 등록으로 바꾸고 data source를 만든다. 프로퍼티 추가:

```swift
    private var dataSource: UITableViewDiffableDataSource<Int, UUID>!
    private var itemsByID: [UUID: DdayData] = [:]
```

`setupTableView`:
```swift
    private func setupTableView() {
        tableView.register(DdayCell.self, forCellReuseIdentifier: DdayCell.reuseID)
        tableView.sectionHeaderTopPadding = 0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90

        dataSource = UITableViewDiffableDataSource<Int, UUID>(tableView: tableView) { [weak self] tableView, indexPath, id in
            let cell = tableView.dequeueReusableCell(withIdentifier: DdayCell.reuseID, for: indexPath) as! DdayCell
            if let data = self?.itemsByID[id] { cell.configure(with: data) }
            return cell
        }
        dataSource.defaultRowAnimation = .fade
        tableView.delegate = self
    }
```

- [ ] **Step 4: applySnapshot 작성 및 reloadAllData 연결**

```swift
    private func applySnapshot(animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([Section.pinned.rawValue, Section.normal.rawValue])
        snapshot.appendItems(pinnedData.compactMap { $0.id }, toSection: Section.pinned.rawValue)
        snapshot.appendItems(unpinnedData.compactMap { $0.id }, toSection: Section.normal.rawValue)
        dataSource.apply(snapshot, animatingDifferences: animated && !Motion.reduce)
    }
```

`reloadAllData`의 마지막 `tableView.reloadData()`를 교체:
```swift
        itemsByID = Dictionary(uniqueKeysWithValues: all.compactMap { d in d.id.map { ($0, d) } })
        applySnapshot(animated: false)
```

- [ ] **Step 5: 데이터 소스가 된 메서드 정리**

`UITableViewDataSource`의 `numberOfSections`, `numberOfRowsInSection`, `cellForRowAt`를 삭제(diffable이 담당). `viewForHeaderInSection`, `heightForHeaderInSection`, `heightForFooterInSection`, `viewForFooterInSection`, `commit editingStyle`, `didSelectRowAt`, `leadingSwipeActions`, `prepare(for:)`는 `UITableViewDelegate`이므로 유지하되 아래 단계에서 수정. `heightForRowAt` 삭제(automaticDimension 사용). extension 선언을 `UITableViewDelegate`만 채택하도록 변경.

- [ ] **Step 6: 헤더 다크모드 수정 + 고정 카운트 노출**

`viewForHeaderInSection`의 `label.textColor = .white` → `.secondaryLabel`. 고정 섹션 헤더 우측에 `2/2` 카운터 추가:

```swift
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        let label = UILabel()
        label.text = section == Section.pinned.rawValue ? "고정" : "나머지"
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .boldSystemFont(ofSize: 18))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        if section == Section.pinned.rawValue {
            let count = UILabel()
            count.text = "\(pinnedData.count)/\(maxPinnedCount)"
            count.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .regular))
            count.adjustsFontForContentSizeCategory = true
            count.textColor = .tertiaryLabel
            count.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(count)
            NSLayoutConstraint.activate([
                count.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                count.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            ])
        }
        return container
    }
```

`heightForHeaderInSection`는 34 유지. 하드코딩 separator 제거(위 코드에서 이미 빠짐).

- [ ] **Step 7: 삭제를 diffable + 햅틱으로**

`commit editingStyle` 교체:
```swift
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, let id = dataSource.itemIdentifier(for: indexPath) else { return }
        let isPinned = indexPath.section == Section.pinned.rawValue
        if isPinned { pinnedData.removeAll { $0.id == id } }
        else { unpinnedData.removeAll { $0.id == id } }
        savePinnedIDs()
        Haptics.delete()
        manager.removeData(id: id) { [weak self] in
            self?.itemsByID[id] = nil
            self?.applySnapshot(animated: true)
        }
    }
```

- [ ] **Step 8: 고정 스와이프를 diffable + 햅틱 + 한도 경고로**

`leadingSwipeActionsConfigurationForRowAt` 교체:
```swift
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let isPinned = indexPath.section == Section.pinned.rawValue
        Haptics.prepareImpact()
        Haptics.prepareNotification()

        if !isPinned && pinnedData.count >= maxPinnedCount {
            let action = UIContextualAction(style: .normal, title: "고정 해제 후 가능") { _, _, completion in
                Haptics.limitWarning()
                completion(false)
            }
            action.image = UIImage(systemName: "pin.slash")
            action.backgroundColor = .systemGray
            return UISwipeActionsConfiguration(actions: [action])
        }

        let title = isPinned ? "고정 해제" : "고정"
        let action = UIContextualAction(style: .normal, title: title) { [weak self] _, _, completion in
            guard let self, let id = self.dataSource.itemIdentifier(for: indexPath),
                  let target = self.itemsByID[id] else { completion(false); return }
            if isPinned {
                self.pinnedData.removeAll { $0.id == id }
                self.unpinnedData.insert(target, at: 0)
            } else {
                self.unpinnedData.removeAll { $0.id == id }
                self.pinnedData.append(target)
            }
            self.savePinnedIDs()
            Haptics.pinToggle()
            self.applySnapshot(animated: !Motion.reduce)
            completion(true)
        }
        action.image = UIImage(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
        action.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [action])
    }
```

- [ ] **Step 9: didSelect / prepare(for:) 를 UUID 기준으로**

`item(at:)` 헬퍼는 `dataSource.itemIdentifier(for:)` + `itemsByID`로 대체한다. `prepare(for:)`에서 `item(at: indexPath)` 대신:
```swift
        if segue.identifier == "DdayViewController", let indexPath = tableView.indexPathForSelectedRow,
           let id = dataSource.itemIdentifier(for: indexPath), let selected = itemsByID[id] {
            // ...기존 목적지 설정 로직에 selected 사용
        }
```
`didSelectRowAt`은 그대로 segue + deselect.

- [ ] **Step 10: setEditing 정리**

`DdayViewController.setEditing`의 `visibleCells` 순회 블록 삭제 — 셀이 자체 `setEditing`으로 처리하므로 `super`만 남긴다:
```swift
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }
```

- [ ] **Step 11: 문구 한국어화**

`setupNavigationBar`의 `title = "Record"` → `"기록"`. `leftBarButton` 제목 `"Edit"`/`"Done"` → `"편집"`/`"완료"` (`leftBarButtonTapped` 내부 포함).

- [ ] **Step 12: 빌드**

Run: 빌드 명령
Expected: `BUILD SUCCEEDED`

- [ ] **Step 13: 시뮬레이터 검증**

- 셀 누르면 떼기 전 축소되는지 (press 피드백)
- 고정/해제 시 행이 섹션 간 이동 애니메이션
- 편집 모드 진입/스크롤 후 새 셀도 D-day 숨김 유지
- 라이트/다크 모드에서 헤더 텍스트 보임
- 고정 2개 후 세 번째 스와이프 시 "고정 해제 후 가능"

Run: iOS Simulator control (attach → build → launch → screenshot, 라이트/다크 각각)

- [ ] **Step 14: 커밋**

```bash
git add -A
git commit -m "feat: 셀 코드 재작성, diffable 리스트, press 피드백, 햅틱, 다크모드 헤더

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: DatePicker 화면 정비

셀 재사용, 델리게이트, 강제 언래핑 정리, 문구, 오타, 저장 햅틱.

**Files:**
- Create: `anneRed/DatePickerCells.swift`
- Modify: `anneRed/DatePickerViewController.swift` (전반)
- Modify: `anneRed/DdayViewController.swift` (델리게이트 채택)
- Modify: `anneRed.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `Haptics`, `DdayCalculator`, `DdayData.id`
- Produces:
  - `protocol DatePickerViewControllerDelegate: AnyObject { func datePickerDidFinish() }`
  - `final class ValueCell: UITableViewCell` (reuseID "ValueCell")
  - `final class InputCell: UITableViewCell` (reuseID "InputCell") — 텍스트필드 소유, `onChange: ((String) -> Void)?`

- [ ] **Step 1: DatePickerCells.swift 생성**

```swift
import UIKit

final class ValueCell: UITableViewCell {
    static let reuseID = "ValueCell"
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, value: String, valueFont: UIFont? = nil) {
        var content = UIListContentConfiguration.valueCell()
        content.text = title
        content.secondaryText = value
        if let f = valueFont { content.secondaryTextProperties.font = f }
        contentConfiguration = content
    }
}

final class InputCell: UITableViewCell {
    static let reuseID = "InputCell"
    private let titleLabel = UILabel()
    let textField = UITextField()
    var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(changed), for: .editingChanged)
        contentView.addSubview(titleLabel)
        contentView.addSubview(textField)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textField.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func changed() { onChange?(textField.text ?? "") }

    func configure(title: String, text: String, placeholder: String, keyboard: UIKeyboardType = .default) {
        titleLabel.text = title
        textField.text = text
        textField.placeholder = placeholder
        textField.keyboardType = keyboard
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onChange = nil
        textField.keyboardType = .default
    }
}
```

- [ ] **Step 2: 델리게이트 프로토콜 정의 + DatePickerViewController 정리**

`DatePickerViewController` 상단에 프로토콜 추가하고 `weak var delegate` 선언. `dismissAndReload`의 4단 캐스팅 체인 전체를 델리게이트 호출로 대체:

```swift
protocol DatePickerViewControllerDelegate: AnyObject {
    func datePickerDidFinish()
}
```

프로퍼티: `weak var delegate: DatePickerViewControllerDelegate?`

`dismissAndReload(originalDate:)` → `dismissAndReload()`:
```swift
    private func dismissAndReload() {
        delegate?.datePickerDidFinish()
        dismiss(animated: true)
    }
```

- [ ] **Step 3: 강제 언래핑 정리 + updateDdayLabel**

`updateDdayLabel`을 `DdayCalculator` 사용 + 언래핑 정리:
```swift
    func updateDdayLabel() {
        let target = datePicker.date
        selectedDate = target
        let daysLeft = DdayCalculator.days(from: Date(), to: target)
        dday = DdayCalculator.text(daysLeft: daysLeft)
        ddayResultText = dday ?? ""
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
    }
```

`rightBarButtonTapped`의 `data!`, `dday!` 정리:
```swift
    @objc func rightBarButtonTapped() {
        updateDdayLabel()
        let finalDday = dday ?? DdayCalculator.text(from: Date(), to: datePicker.date)
        if let existing = data {
            existing.dday = finalDday
            existing.title = titleText
            existing.selectedDate = selectedDate
            manager.updateData(targetId: existing.selectedDate ?? Date(), newData: existing) {
                self.dismissAndReload()
            }
        } else {
            manager.saveData(title: titleText.isEmpty ? "empty" : titleText, dday: finalDday, selectedDate: selectedDate) {
                Haptics.saveSuccess()
                self.dismissAndReload()
            }
        }
    }
```

- [ ] **Step 4: 오타 정정**

`caculInputText`→`calcInputText`, `caculResultText`→`calcResultText`, `caculateDay`→`calculateDay`, `caculTextFieldChanged`→`calcTextFieldChanged`. 전 참조 갱신.

- [ ] **Step 5: cellForRowAt를 재사용 셀로 재작성**

`setupTableView`에서 등록:
```swift
        tableView.register(ValueCell.self, forCellReuseIdentifier: ValueCell.reuseID)
        tableView.register(InputCell.self, forCellReuseIdentifier: InputCell.reuseID)
```

`cellForRowAt` 재작성:
```swift
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: ValueCell.reuseID, for: indexPath) as! ValueCell
            cell.configure(title: "D-Day", value: ddayResultText,
                           valueFont: .systemFont(ofSize: 22, weight: .medium))
            return cell
        }
        if indexPath.section == 0 && indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: InputCell.reuseID, for: indexPath) as! InputCell
            cell.configure(title: "제목", text: titleText, placeholder: "제목")
            cell.onChange = { [weak self] in self?.titleText = $0 }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: InputCell.reuseID, for: indexPath) as! InputCell
        cell.configure(title: "일수", text: calcInputText, placeholder: "일수", keyboard: .numberPad)
        cell.onChange = { [weak self] in
            self?.calcInputText = $0
            self?.calculateDay()
        }
        return cell
    }
```

계산 결과 표시(`calcResultText`)는 계산 셀 아래 표시가 필요하므로, `calculateDay` 후 `tableView.reloadRows`로 계산 행을 갱신하되 입력 포커스 유지를 위해 결과는 `InputCell`의 placeholder나 별도 detail로 노출한다. 단순화를 위해 계산 결과는 `datePicker` 아래 섹션 헤더/푸터 텍스트로 표시:

`titleForFooterInSection`:
```swift
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 1 ? (calcResultText.isEmpty ? nil : calcResultText) : nil
    }
```
`calculateDay` 끝에서 `tableView.footerView(forSection: 1)` 갱신 대신 `tableView.reloadSections`는 포커스를 깨므로, footer만 직접 갱신:
```swift
        UIView.performWithoutAnimation {
            self.tableView.footerView(forSection: 1)?.textLabel?.text = self.calcResultText
            self.tableView.footerView(forSection: 1)?.textLabel?.setNeedsLayout()
        }
```

- [ ] **Step 6: 신규/편집 타이틀 분기 + 문구**

`setupNavigationBar`:
```swift
        title = (data == nil) ? "새 D-Day" : "편집"
        let leftBarButton = UIBarButtonItem(title: "취소", style: .plain, target: self, action: #selector(leftBarButtonTapped))
        let rightBarButton = UIBarButtonItem(title: "저장", style: .plain, target: self, action: #selector(rightBarButtonTapped))
```
`titleForHeaderInSection`의 `"선택한 날짜로부터 계산하기"` 유지(이미 한국어).

- [ ] **Step 7: DdayViewController가 델리게이트 채택 + segue에서 delegate 지정**

`DdayViewController`에 확장:
```swift
extension DdayViewController: DatePickerViewControllerDelegate {
    func datePickerDidFinish() { reloadAllData() }
}
```
`rightBarButtonTapped`(add) 및 `prepare(for:)`(edit) 두 경로에서 `datePickerViewController.delegate = self` 설정.

- [ ] **Step 8: project.pbxproj 등록 + 빌드**

`DatePickerCells.swift` 등록 후 빌드.
Run: 빌드 명령 → `BUILD SUCCEEDED`

- [ ] **Step 9: 시뮬레이터 검증**

- 제목 입력 중 날짜 변경 시 포커스·내용 유지
- 기존 항목 탭 시 타이틀 "편집"
- 저장 시 성공 햅틱
- 계산 입력 시 결과 표시

- [ ] **Step 10: 커밋**

```bash
git add -A
git commit -m "refactor: DatePicker 셀 재사용, 델리게이트, 언래핑·오타 정리, 저장 햅틱

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Reduced Motion 런타임 대응 + 죽은 코드·문구 마무리

**Files:**
- Modify: `anneRed/DdayViewController.swift`
- Delete: `anneRed/ViewController.swift`, `anneRed/Model.swift`
- Modify: `anneRed/DdayDataManager.swift`, `anneRed/DdayNavigationViewController.swift`, `anneRed/DatePickerNavigationViewController.swift`
- Modify: `anneRed/Base.lproj/Main.storyboard`
- Modify: `anneRed.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `Motion`
- Produces: 없음 (정리 태스크)

- [ ] **Step 1: Reduce Motion 런타임 변경 구독**

`DdayViewController.viewDidLoad`에 옵저버 추가 (스냅샷 재적용으로 애니메이션 설정 반영):
```swift
        NotificationCenter.default.addObserver(
            self, selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
```
```swift
    @objc private func reduceMotionChanged() { applySnapshot(animated: false) }
```
`deinit`에서 `NotificationCenter.default.removeObserver(self)`가 전체 제거하는지 확인(현재는 특정 이름만 제거하므로 `removeObserver(self)`로 통합).

- [ ] **Step 2: 죽은 파일 삭제**

```bash
git rm anneRed/ViewController.swift anneRed/Model.swift
```
`project.pbxproj`에서 두 파일의 엔트리 제거. `Model` 참조가 남았는지 확인: `TableViewCell`은 이미 삭제됨. `DdayDataManager`에 `Model` 참조 없음.

- [ ] **Step 3: 빈 오버라이드·print 제거**

- `DdayNavigationViewController.viewDidLoad`, `DatePickerNavigationViewController.viewDidLoad` 빈 오버라이드 삭제 (클래스 본문을 비운다)
- `DdayViewController`의 빈 `viewDidAppear`, `viewWillDisappear` 삭제
- `DdayDataManager`의 `print("error")` 3곳, `saveWidgetData`의 `print` 3곳 제거
- `DdayViewController.saveWidgetData`의 `print` 문 제거

- [ ] **Step 4: 탭바 "Item 1" → "기록"**

`Base.lproj/Main.storyboard`에서 `<tabBarItem key="tabBarItem" title="Item 1"`을 `title="기록"`으로 수정.

- [ ] **Step 5: 빌드**

Run: 빌드 명령 → `BUILD SUCCEEDED`

- [ ] **Step 6: 시뮬레이터 검증 — Reduced Motion**

설정 > 손쉬운 사용 > 동작 > 동작 줄이기 ON 상태에서 고정/삭제가 스프링 없이 크로스페이드로 처리되는지, 탭바 첫 항목이 "기록"인지 확인.

- [ ] **Step 7: 커밋**

```bash
git add -A
git commit -m "chore: Reduced Motion 대응, 죽은 코드 제거, 탭바 문구 정리

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: 전체 회귀 검증

**Files:** 없음 (검증만)

- [ ] **Step 1: 클린 빌드**

Run:
```bash
cd /Users/zongbeen/Desktop/anneRed/anneRed && xcodebuild -project anneRed.xcodeproj -scheme anneRed -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: 위젯 타깃 빌드**

Run:
```bash
cd /Users/zongbeen/Desktop/anneRed/anneRed && xcodebuild -project anneRed.xcodeproj -scheme DdayWidgetExtension -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED` (위젯 데이터 계약이 깨지지 않았는지)

- [ ] **Step 3: 시나리오 전수 검증 (시뮬레이터)**

라이트/다크 각각에서:
1. 신규 추가 → 저장 햅틱 → 목록에 애니메이션으로 등장
2. 같은 날짜 2개 → 독립 고정/삭제
3. 고정 2개 → 3번째 스와이프 경고
4. 항목 편집 → 날짜 변경 → 고정 유지
5. 편집 모드 → 스크롤 → 삭제
6. 텍스트 크기 최대 → 셀 확장, 숫자 폭 안정
7. Reduce Motion ON → 크로스페이드

- [ ] **Step 4: 최종 정리 커밋 (있으면)**

검증 중 발견한 소소한 수정이 있으면 커밋. 없으면 스킵.

---

## Self-Review 결과

- **스펙 커버리지**: 스펙 §1→Task 2·3, §2→Task 5, §3→Task 5, §4→Task 4·5, §5→Task 6, §6→Task 7, §7→Task 7. 전 섹션 매핑됨.
- **타입 일관성**: `removeData(id:)`, `applySnapshot(animated:)`, `DdayCell.reuseID`, `Motion.spring(bounce:duration:)`, `Haptics.*`, `DatePickerViewControllerDelegate.datePickerDidFinish()` — 정의처와 사용처 일치 확인.
- **알려진 리스크**: (a) 신규 `.swift` 파일의 `project.pbxproj` 수동 등록이 실패하기 쉬움 — 각 파일 태스크에 등록 스텝 포함. (b) DatePicker 계산 결과의 footer 갱신이 포커스를 깨지 않는지 Task 6 Step 5에서 실측 필요. (c) `updateData`가 `targetId`를 실제로 쓰지 않으므로(이미 managed object) 인자는 형식상 전달.
