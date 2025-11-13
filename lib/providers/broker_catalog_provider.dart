import 'package:flutter/foundation.dart';
import '../models/catalog/broker_catalog.dart';
import '../services/catalog/catalog_service.dart';
import '../services/broker_settings_service.dart';

/// Provider for managing broker catalog state
///
/// Handles:
/// - Loading catalogs from CatalogService
/// - Search and filter functionality
/// - Broker selection and persistence
/// - Error handling and loading states
class BrokerCatalogProvider extends ChangeNotifier {
  final CatalogService _catalogService;
  final BrokerSettingsService _settingsService;

  List<BrokerCatalog> _catalogs = [];
  List<BrokerCatalog> _filteredCatalogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  BrokerCatalog? _selectedBroker;
  String _searchQuery = '';
  String _platformFilter = 'all'; // 'all', 'mt4', 'mt5'

  BrokerCatalogProvider(this._catalogService, this._settingsService);

  // Getters
  List<BrokerCatalog> get catalogs => _filteredCatalogs.isNotEmpty ? _filteredCatalogs : _catalogs;
  List<BrokerCatalog> get allCatalogs => _catalogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  BrokerCatalog? get selectedBroker => _selectedBroker;
  String get searchQuery => _searchQuery;
  String get platformFilter => _platformFilter;
  bool get hasSelectedBroker => _selectedBroker != null;
  int get catalogCount => _catalogs.length;

  /// Initialize provider and load saved broker
  Future<void> initialize() async {
    await loadSavedBroker();
  }

  /// Load all broker catalogs
  ///
  /// Downloads catalogs from GitHub or loads from cache.
  /// Updates UI state during loading.
  Future<void> loadCatalogs({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('📂 Loading broker catalogs...');

      final loadedCatalogs = forceRefresh
          ? await _catalogService.refreshAllCatalogs()
          : await _catalogService.loadAllCatalogs();

      _catalogs = loadedCatalogs;
      _applyFilters();

      debugPrint('✓ Loaded ${_catalogs.length} broker catalogs');
    } catch (e) {
      debugPrint('✗ Error loading catalogs: $e');
      _errorMessage = 'Failed to load broker catalogs: $e';
      _catalogs = [];
      _filteredCatalogs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh catalogs (force download)
  Future<void> refreshCatalogs() async {
    await loadCatalogs(forceRefresh: true);
  }

  /// Search brokers by query
  ///
  /// Searches in: name, country, currencies, instruments
  void searchBrokers(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Filter brokers by platform
  ///
  /// Options: 'all', 'mt4', 'mt5'
  void filterByPlatform(String platform) {
    _platformFilter = platform;
    _applyFilters();
    notifyListeners();
  }

  /// Apply current search and filter settings
  void _applyFilters() {
    var filtered = List<BrokerCatalog>.from(_catalogs);

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();

      filtered = filtered.where((catalog) {
        // Search in broker name
        if (catalog.catalogName.toLowerCase().contains(query)) {
          return true;
        }

        // Search in country
        if (catalog.metadata?.country?.toLowerCase().contains(query) == true) {
          return true;
        }

        // Search in currencies
        if (catalog.features?.currencies?.any((c) => c.toLowerCase().contains(query)) == true) {
          return true;
        }

        // Search in instruments
        if (catalog.features?.instruments?.any((i) => i.toLowerCase().contains(query)) == true) {
          return true;
        }

        return false;
      }).toList();
    }

    // Apply platform filter
    if (_platformFilter == 'mt4') {
      filtered = filtered.where((catalog) => catalog.platforms.mt4.available).toList();
    } else if (_platformFilter == 'mt5') {
      filtered = filtered.where((catalog) => catalog.platforms.mt5.available).toList();
    }

    _filteredCatalogs = filtered;
  }

  /// Clear search and filters
  void clearFilters() {
    _searchQuery = '';
    _platformFilter = 'all';
    _filteredCatalogs = [];
    notifyListeners();
  }

  /// Select a broker and save to settings
  Future<void> selectBroker(BrokerCatalog catalog) async {
    try {
      debugPrint('✓ Selecting broker: ${catalog.catalogName}');

      // Save to SharedPreferences
      await _settingsService.saveSelectedBroker(catalog);

      _selectedBroker = catalog;
      notifyListeners();

      debugPrint('✓ Broker selected and saved');
    } catch (e) {
      debugPrint('✗ Error selecting broker: $e');
      _errorMessage = 'Failed to save broker selection: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Clear broker selection
  Future<void> clearSelection() async {
    try {
      await _settingsService.clearSelectedBroker();
      _selectedBroker = null;
      notifyListeners();

      debugPrint('✓ Broker selection cleared');
    } catch (e) {
      debugPrint('✗ Error clearing selection: $e');
      rethrow;
    }
  }

  /// Load previously selected broker from SharedPreferences
  Future<void> loadSavedBroker() async {
    try {
      final brokerId = await _settingsService.getSelectedBrokerId();

      if (brokerId != null) {
        debugPrint('📂 Loading saved broker: $brokerId');

        // Try to load from catalog service (cache-first)
        final catalog = await _catalogService.loadCatalog(brokerId);
        _selectedBroker = catalog;

        debugPrint('✓ Loaded saved broker: ${catalog.catalogName}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️  Could not load saved broker: $e');
      // Non-fatal error - user can select a new broker
    }
  }

  /// Get catalog by ID
  BrokerCatalog? getCatalogById(String catalogId) {
    try {
      return _catalogs.firstWhere((c) => c.catalogId == catalogId);
    } catch (e) {
      return null;
    }
  }

  /// Check if a specific broker is selected
  bool isBrokerSelected(String catalogId) {
    return _selectedBroker?.catalogId == catalogId;
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() {
    final mt4Count = _catalogs.where((c) => c.platforms.mt4.available).length;
    final mt5Count = _catalogs.where((c) => c.platforms.mt5.available).length;
    final bothCount = _catalogs.where((c) =>
        c.platforms.mt4.available && c.platforms.mt5.available).length;

    return {
      'total_brokers': _catalogs.length,
      'mt4_brokers': mt4Count,
      'mt5_brokers': mt5Count,
      'both_platforms': bothCount,
      'has_selected': _selectedBroker != null,
      'selected_broker_name': _selectedBroker?.catalogName,
    };
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Clean up if needed
    super.dispose();
  }
}
