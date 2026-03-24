# Myhealth App - Memory

## Project Structure
- Path: `/Users/ximapika/Xcode/Myhealth/`
- Xcode project: `Myhealth.xcodeproj` (uses PBXFileSystemSynchronizedRootGroup - auto-syncs Swift files)
- Source files: `Myhealth/` folder
- iOS deployment target: 26.2 (iOS 26)
- Swift default actor isolation: MainActor (set in build settings)

## Architecture
| File | Purpose |
|------|---------|
| `Models.swift` | Data models: MealRecord, WeightRecord, DailyEnergy, DailySummary, Report |
| `DataStore.swift` | Singleton ObservableObject, UserDefaults persistence for meals/weights/energies/reports |
| `HealthKitManager.swift` | Singleton ObservableObject, reads basalEnergyBurned, activeEnergyBurned, sleepAnalysis |
| `AIService.swift` | Claude claude-opus-4-6 API calls: meal calorie analysis (vision), daily report, weekly report |
| `ContentView.swift` | TabView root: Today / Meals / History / Reports / Settings |
| `DashboardView.swift` | Energy ring, stat cards, meal summary, net energy, weight input |
| `MealView.swift` | Per-meal photo upload + AI calorie analysis (PhotosPicker) |
| `HistoryView.swift` | Charts (Swift Charts): energy burned+intake, weight, sleep (week/month) |
| `ReportView.swift` | Generate daily/weekly AI reports, display with expand/collapse |
| `SettingsView.swift` | API key input (SecureField), HealthKit status, data counts |

## Key Details
- AI: Claude claude-opus-4-6 via Anthropic API (`https://api.anthropic.com/v1/messages`)
- API key stored in UserDefaults key `anthropic_api_key`
- Privacy keys added to `.pbxproj`: NSHealthShareUsageDescription, NSPhotoLibraryUsageDescription
- HealthKit capability must be added manually in Xcode → Signing & Capabilities
- Sleep window: previous day noon → current day noon
- Data persistence: JSON in UserDefaults (not CoreData)

## User Preferences
- AI: Claude (Anthropic)
- API key: entered in Settings screen
- Language: English (iPhone default is English)
- UI: clean but visually appealing (uses .ultraThinMaterial, rounded cards)
