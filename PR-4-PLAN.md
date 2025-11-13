# PR-4: Broker Selection UI - Implementation Plan

**Branch:** `feature/pr4-broker-selection-ui`
**Base:** `feature/pr3-android-catalog-loader`
**Status:** 📝 Planning Phase
**Date:** 2025-11-12

---

## 📋 Overview

Implement a comprehensive broker selection UI that allows users to browse, search, filter, and select MT4/MT5 brokers from the dynamically loaded catalogs (PR-3). Selected broker details are persisted and used for MT4/MT5 API configuration.

---

## 🎯 Objectives

### Primary Goals

1. **Broker List Screen** - Display all available brokers from catalogs
2. **Broker Details Screen** - Show complete broker information
3. **Search & Filter** - Find brokers by name, country, features
4. **Broker Selection** - Save selected broker to app settings
5. **Server Configuration** - Display MT4/MT5 server details for setup
6. **Offline Support** - Works with cached catalogs when offline

### User Flow

```
App Launch
    │
    ├─► First Time User
    │   └─► Broker Selection Screen
    │       ├─► Browse Catalogs
    │       ├─► Search/Filter
    │       ├─► View Broker Details
    │       └─► Select Broker → Save Settings → Continue to Trading
    │
    └─► Returning User
        ├─► Skip to Trading Dashboard (saved broker)
        └─► Settings → Change Broker → Broker Selection Screen
```

---

## 🏗️ Architecture

### State Management

Using **Provider** (already in project):

```
BrokerCatalogProvider
├── State: List<BrokerCatalog> catalogs
├── State: bool isLoading
├── State: String? errorMessage
├── State: BrokerCatalog? selectedBroker
├── Method: loadCatalogs()
├── Method: refreshCatalogs()
├── Method: selectBroker(catalog)
├── Method: clearSelection()
└── Method: searchBrokers(query)
```

### Persistence

Using **SharedPreferences** for selected broker:

```dart
// Save selected broker
prefs.setString('selected_broker_id', 'sample-broker-1');
prefs.setString('selected_broker_name', 'Sample Broker');
prefs.setString('selected_mt4_server', 'SampleBroker-Live');
prefs.setString('selected_mt5_server', 'SampleBroker-Live5');

// Retrieve on app startup
final brokerId = prefs.getString('selected_broker_id');
```

### Navigation

```
lib/
├── screens/
│   ├── broker_selection/
│   │   ├── broker_list_screen.dart
│   │   ├── broker_details_screen.dart
│   │   └── broker_search_screen.dart
│   └── settings/
│       └── broker_settings_screen.dart
└── providers/
    └── broker_catalog_provider.dart
```

---

## 📱 UI Screens

### 1. Broker List Screen

**Purpose:** Browse all available brokers

**Layout:**
```
┌─────────────────────────────────┐
│ ← Back    Broker Selection  🔍  │ ← AppBar with search icon
├─────────────────────────────────┤
│ 📊 12 Brokers Available         │ ← Summary banner
│ ✓ All verified with signatures  │
├─────────────────────────────────┤
│ 🔽 Filter: All | MT4 | MT5     │ ← Filter chips
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🏢 Sample Broker 1          │ │ ← Broker card
│ │ 🌍 United States            │ │
│ │ 📈 MT4 ✓ | MT5 ✓           │ │
│ │ 💰 Min: $100 | Leverage: 1:500│
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 🏢 Sample Broker 2          │ │
│ │ 🌍 United Kingdom           │ │
│ │ 📈 MT4 ✓ | MT5 ✓           │ │
│ │ 💰 Min: $500 | Leverage: 1:200│
│ └─────────────────────────────┘ │
│ ...                             │
└─────────────────────────────────┘
```

**Features:**
- Card-based list view
- Tap card → Navigate to details
- Pull-to-refresh for catalog updates
- Loading indicator while fetching
- Error message with retry button
- Empty state if no catalogs

**Widgets:**
```dart
BrokerListScreen
├── AppBar (title, search icon)
├── BrokerSummaryBanner (count, status)
├── BrokerFilterChips (All, MT4 only, MT5 only)
├── RefreshIndicator
└── ListView.builder
    └── BrokerCard (foreach catalog)
        ├── Broker name
        ├── Country flag + name
        ├── Platform badges (MT4/MT5)
        ├── Quick info (min deposit, leverage)
        └── onTap: Navigate to details
```

### 2. Broker Details Screen

**Purpose:** Show complete broker information

**Layout:**
```
┌─────────────────────────────────┐
│ ← Back    Sample Broker 1       │ ← AppBar
├─────────────────────────────────┤
│ 🏢 Sample Broker 1              │ ← Header
│ 🌍 United States | 🏛️ Regulated │
│ [Select This Broker] Button     │ ← Primary action
├─────────────────────────────────┤
│ 📊 Trading Platforms            │
│ ┌─────────────────┐             │
│ │ MT4 Available   │             │
│ │ Server: SampleBroker-Live     │
│ └─────────────────┘             │
│ ┌─────────────────┐             │
│ │ MT5 Available   │             │
│ │ Server: SampleBroker-Live5    │
│ └─────────────────┘             │
├─────────────────────────────────┤
│ 💰 Trading Conditions           │
│ • Min Deposit: $100             │
│ • Max Leverage: 1:500           │
│ • Spreads: From 0.1 pips        │
│ • Commission: $3.5/lot          │
├─────────────────────────────────┤
│ 📈 Account Types                │
│ • Standard (Min: $100)          │
│ • ECN (Min: $500)               │
│ • Islamic (Swap-free)           │
├─────────────────────────────────┤
│ 📞 Contact Information          │
│ • Email: support@example.com    │
│ • Phone: +1-xxx-xxx-xxxx        │
│ • Live Chat: Available          │
└─────────────────────────────────┘
```

**Features:**
- Detailed broker information
- Platform availability (MT4/MT5)
- Server names for manual configuration
- Trading conditions and fees
- Account types with minimums
- Contact information
- "Select This Broker" button
- Share broker info button

**Widgets:**
```dart
BrokerDetailsScreen
├── AppBar (title, share icon)
├── BrokerHeader
│   ├── Broker name + logo
│   ├── Country + regulation badges
│   └── SelectBrokerButton (primary action)
├── PlatformsSection
│   ├── MT4 card (if available)
│   │   ├── Server name (copyable)
│   │   └── Demo server (if available)
│   └── MT5 card (if available)
├── TradingConditionsSection
│   └── Expandable details
├── AccountTypesSection
│   └── List of account types
├── FeaturesSection (instruments, spreads)
├── ContactSection
└── DisclaimerSection
```

### 3. Broker Search Screen

**Purpose:** Search and filter brokers

**Layout:**
```
┌─────────────────────────────────┐
│ [Search brokers...] ← ✖         │ ← Search bar
├─────────────────────────────────┤
│ Recent Searches:                │
│ • "low spread"                  │
│ • "islamic account"             │
├─────────────────────────────────┤
│ Popular Filters:                │
│ • MT4 Only                      │
│ • MT5 Only                      │
│ • Low Min Deposit (<$500)       │
│ • High Leverage (>1:400)        │
│ • Swap-Free                     │
├─────────────────────────────────┤
│ Search Results (5):             │
│ [Broker cards matching query]   │
└─────────────────────────────────┘
```

**Features:**
- Real-time search as you type
- Search by: name, country, features
- Filter by: platform, deposit, leverage
- Recent searches (saved locally)
- Popular filter chips
- Clear search button

**Search Logic:**
```dart
List<BrokerCatalog> searchBrokers(String query) {
  query = query.toLowerCase();

  return catalogs.where((catalog) {
    return catalog.catalogName.toLowerCase().contains(query) ||
           catalog.metadata?.country?.toLowerCase().contains(query) ||
           catalog.features?.currencies?.any((c) => c.toLowerCase().contains(query)) == true;
  }).toList();
}
```

### 4. Broker Settings Screen

**Purpose:** Manage saved broker configuration

**Layout:**
```
┌─────────────────────────────────┐
│ ← Back    Broker Settings        │
├─────────────────────────────────┤
│ Current Broker                  │
│ ┌─────────────────────────────┐ │
│ │ 🏢 Sample Broker 1          │ │
│ │ 🌍 United States            │ │
│ │ 📈 MT4: SampleBroker-Live   │ │
│ │ [Change Broker]             │ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ MT4/MT5 Configuration           │
│ • Platform: MT4                 │
│ • Server: SampleBroker-Live     │
│ • Login: (Configure in MT4)     │
│ • Password: (Configure in MT4)  │
├─────────────────────────────────┤
│ Bridge Server                   │
│ • URL: http://192.168.1.100:8080│
│ • Status: ⚠️ Not Connected     │
│ [Test Connection]               │
└─────────────────────────────────┘
```

**Features:**
- Display currently selected broker
- Change broker button → Broker List
- Show broker's MT4/MT5 servers
- Bridge server configuration
- Connection test button

---

## 🔧 Implementation Tasks

### Phase 1: State Management & Services (2 hours)

**1.1 Create BrokerCatalogProvider**

File: `lib/providers/broker_catalog_provider.dart`

```dart
class BrokerCatalogProvider extends ChangeNotifier {
  final CatalogService _catalogService;

  List<BrokerCatalog> _catalogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  BrokerCatalog? _selectedBroker;

  // Getters
  List<BrokerCatalog> get catalogs => _catalogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  BrokerCatalog? get selectedBroker => _selectedBroker;

  // Load catalogs
  Future<void> loadCatalogs() async { ... }

  // Refresh catalogs
  Future<void> refreshCatalogs() async { ... }

  // Select broker
  Future<void> selectBroker(BrokerCatalog catalog) async { ... }

  // Search
  List<BrokerCatalog> searchBrokers(String query) { ... }

  // Filter
  List<BrokerCatalog> filterByPlatform(String platform) { ... }
}
```

**1.2 Create BrokerSettingsService**

File: `lib/services/broker_settings_service.dart`

```dart
class BrokerSettingsService {
  final SharedPreferences _prefs;

  // Save selected broker
  Future<void> saveSelectedBroker(BrokerCatalog catalog);

  // Load selected broker
  Future<String?> getSelectedBrokerId();

  // Get broker servers
  Future<Map<String, String>> getBrokerServers();

  // Clear selection
  Future<void> clearSelectedBroker();
}
```

### Phase 2: UI Components (3 hours)

**2.1 Broker Card Widget**

File: `lib/widgets/broker_card.dart`

- Reusable card for broker list
- Shows: name, country, platforms, quick info
- onTap callback

**2.2 Platform Badge Widget**

File: `lib/widgets/platform_badge.dart`

- MT4/MT5 badges
- Conditional rendering based on availability

**2.3 Broker Summary Banner**

File: `lib/widgets/broker_summary_banner.dart`

- Shows count of available brokers
- Verification status
- Last updated time

### Phase 3: Screens Implementation (4 hours)

**3.1 Broker List Screen**

File: `lib/screens/broker_selection/broker_list_screen.dart`

- Uses BrokerCatalogProvider
- ListView with BrokerCard
- Pull-to-refresh
- Navigate to details on tap
- Loading/error states

**3.2 Broker Details Screen**

File: `lib/screens/broker_selection/broker_details_screen.dart`

- Receives BrokerCatalog as parameter
- Sections: platforms, conditions, accounts, contact
- "Select This Broker" button
- Save to SharedPreferences

**3.3 Broker Search Screen**

File: `lib/screens/broker_selection/broker_search_screen.dart`

- Search bar with clear button
- Real-time filtering
- Recent searches
- Filter chips

**3.4 Broker Settings Screen**

File: `lib/screens/settings/broker_settings_screen.dart`

- Display current broker
- Change broker button
- Server details
- Bridge configuration

### Phase 4: Navigation & Integration (2 hours)

**4.1 Update Main App**

File: `lib/main.dart`

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => BrokerCatalogProvider(catalogService)..loadCatalogs(),
    ),
    // ... other providers
  ],
  child: MaterialApp(
    routes: {
      '/broker-selection': (context) => BrokerListScreen(),
      '/broker-details': (context) => BrokerDetailsScreen(),
      '/broker-search': (context) => BrokerSearchScreen(),
      '/broker-settings': (context) => BrokerSettingsScreen(),
    },
  ),
)
```

**4.2 First-Time Setup Flow**

- Check if broker selected on app launch
- If not → Show broker selection
- If yes → Show trading dashboard

**4.3 Settings Integration**

- Add "Change Broker" option in Settings
- Navigate to broker selection

### Phase 5: Persistence (1 hour)

**5.1 Save Selected Broker**

```dart
Future<void> _saveSelectedBroker(BrokerCatalog catalog) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('selected_broker_id', catalog.catalogId);
  await prefs.setString('selected_broker_name', catalog.catalogName);

  if (catalog.platforms.mt4.available) {
    await prefs.setString('mt4_server', catalog.platforms.mt4.liveServers.first);
  }

  if (catalog.platforms.mt5.available) {
    await prefs.setString('mt5_server', catalog.platforms.mt5.liveServers.first);
  }
}
```

**5.2 Load on Startup**

```dart
Future<void> _loadSelectedBroker() async {
  final prefs = await SharedPreferences.getInstance();
  final brokerId = prefs.getString('selected_broker_id');

  if (brokerId != null) {
    // Load full catalog from cache or download
    final catalog = await catalogService.loadCatalog(brokerId);
    setState(() => selectedBroker = catalog);
  }
}
```

### Phase 6: Testing (2 hours)

**6.1 Widget Tests**

- BrokerCard rendering
- Platform badges
- Search functionality
- Filter logic

**6.2 Integration Tests**

- Full broker selection flow
- Persistence across app restarts
- Offline behavior with cached catalogs

**6.3 Manual Testing**

- Test with sample-broker-1 and sample-broker-2
- Verify server details displayed correctly
- Test search and filter
- Verify selection persists

---

## 📊 Data Flow

```
App Launch
    │
    ├─► BrokerCatalogProvider.loadCatalogs()
    │   └─► CatalogService.loadAllCatalogs()
    │       ├─► Check Hive cache
    │       ├─► Download from GitHub (if needed)
    │       └─► Verify Ed25519 signatures
    │
    ├─► BrokerListScreen displays catalogs
    │   └─► User taps broker card
    │       └─► Navigate to BrokerDetailsScreen
    │           └─► User taps "Select This Broker"
    │               ├─► Save to SharedPreferences
    │               ├─► Update provider state
    │               └─► Navigate to Trading Dashboard
    │
    └─► Load saved broker on next launch
        └─► CatalogService.loadCatalog(savedId)
            └─► Use cached data (fast)
```

---

## 🎨 UI/UX Guidelines

### Design Principles

1. **Material Design 3** - Follow existing app theme
2. **Clear Information Hierarchy** - Name > Country > Platforms > Details
3. **Touch-Friendly** - Minimum 48dp touch targets
4. **Responsive** - Works on phones and tablets
5. **Loading States** - Show progress during network operations
6. **Error Handling** - Clear error messages with retry options
7. **Accessibility** - Proper labels and contrast ratios

### Colors & Icons

```dart
// Broker card
Card(
  elevation: 2,
  margin: EdgeInsets.all(8),
  child: InkWell(onTap: ...),
)

// Platform badges
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: Colors.blue[100],
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text('MT4', style: TextStyle(color: Colors.blue[800])),
)

// Icons
🏢 - Icons.business (broker)
🌍 - Icons.public (country)
📈 - Icons.show_chart (platforms)
💰 - Icons.attach_money (deposit)
📞 - Icons.phone (contact)
```

---

## 🔐 Security Considerations

### Input Validation

- Sanitize search queries
- Validate broker selection before saving
- Verify catalog data integrity

### Data Privacy

- Don't store sensitive broker credentials
- Only store broker ID and server names
- Actual login/password entered in MT4/MT5

### Error Handling

- Don't expose internal errors to users
- Log errors for debugging
- Graceful degradation if catalogs unavailable

---

## 📝 Acceptance Criteria

### From PR-1 Directive

- [x] **Broker selection UI for choosing broker from catalogs**
  - Broker list screen
  - Broker details screen
  - Search and filter

- [x] **Display broker metadata, platforms, trading conditions**
  - Show all catalog fields in UI
  - MT4/MT5 availability
  - Server names
  - Trading conditions

- [x] **Save selected broker to SharedPreferences**
  - Persist broker ID
  - Persist server names
  - Load on app startup

- [x] **First-time setup wizard to select broker**
  - Check if broker selected
  - Show selection if not
  - Skip if already selected

- [x] **Graceful handling of catalog loading errors**
  - Show error message
  - Retry button
  - Fallback to cached data

### Additional Features

- [ ] Broker comparison (future enhancement)
- [ ] Favorite brokers (future enhancement)
- [ ] Rating/reviews (future enhancement - requires backend)

---

## 📚 Dependencies

### Required (Already in Project)

- `provider: ^6.0.5` - State management
- `shared_preferences: ^2.2.2` - Persistence
- `flutter_svg: ^2.0.9` - Country flags (if added)

### Optional Enhancements

- `cached_network_image: ^3.3.0` - Broker logos (if added)
- `shimmer: ^3.0.0` - Loading skeletons
- `flutter_slidable: ^3.0.1` - Swipe actions

---

## 🚀 Development Timeline

| Phase | Task | Time | Cumulative |
|-------|------|------|------------|
| 1 | State Management | 2h | 2h |
| 2 | UI Components | 3h | 5h |
| 3 | Screens | 4h | 9h |
| 4 | Navigation | 2h | 11h |
| 5 | Persistence | 1h | 12h |
| 6 | Testing | 2h | 14h |
| 7 | Documentation | 1h | 15h |

**Total Estimated Time:** 15 hours (~2 days)

---

## 🔗 Related Files

### Created in PR-3 (Dependencies)

- `lib/services/catalog/catalog_service.dart` - Load catalogs
- `lib/models/catalog/broker_catalog.dart` - Catalog models
- `lib/constants/catalog_constants.dart` - Configuration

### To Be Created in PR-4

```
lib/
├── providers/
│   └── broker_catalog_provider.dart
├── services/
│   └── broker_settings_service.dart
├── screens/
│   ├── broker_selection/
│   │   ├── broker_list_screen.dart
│   │   ├── broker_details_screen.dart
│   │   └── broker_search_screen.dart
│   └── settings/
│       └── broker_settings_screen.dart
└── widgets/
    ├── broker_card.dart
    ├── platform_badge.dart
    ├── broker_summary_banner.dart
    └── broker_info_section.dart
```

---

## 📖 Documentation Plan

### PR-4.md (Complete Reference)

- Architecture overview
- State management patterns
- UI screenshots
- Code examples
- Testing guide
- Next steps (PR-5)

### README.md Updates

- Add broker selection section
- Update setup instructions
- Add screenshots

---

## ✅ Success Metrics

### Functional

- ✅ User can browse all catalogs
- ✅ User can search brokers
- ✅ User can view complete broker details
- ✅ User can select a broker
- ✅ Selection persists across app restarts
- ✅ Works offline with cached catalogs

### Non-Functional

- ✅ List loads in <2 seconds (cached)
- ✅ Search responds in <500ms
- ✅ Smooth scrolling (60fps)
- ✅ No memory leaks
- ✅ Accessible UI (contrast, labels)

---

## 🎯 Next Steps After PR-4

**PR-5: Full Secure Release Pipeline**
- Automated APK signing
- GitHub releases with changelog
- Version management
- Security scanning

**PR-6: Documentation Overhaul**
- Complete user guide
- Developer documentation
- API reference
- Video tutorials

---

**Status:** 📝 Planning Complete - Ready for Implementation

**Branch:** Will create `feature/pr4-broker-selection-ui` from PR-3

**Estimated Completion:** 2 days

**Dependencies:** PR-3 (catalog services)
