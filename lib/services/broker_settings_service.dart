import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/catalog/broker_catalog.dart';

/// Service for persisting selected broker settings
///
/// Uses SharedPreferences to store:
/// - Selected broker ID
/// - Broker name
/// - MT4/MT5 server names
/// - Platform preference
class BrokerSettingsService {
  static const String _keyBrokerId = 'selected_broker_id';
  static const String _keyBrokerName = 'selected_broker_name';
  static const String _keyMT4Server = 'mt4_server';
  static const String _keyMT5Server = 'mt5_server';
  static const String _keyMT4DemoServer = 'mt4_demo_server';
  static const String _keyMT5DemoServer = 'mt5_demo_server';
  static const String _keyPreferredPlatform = 'preferred_platform';
  static const String _keyBrokerCountry = 'broker_country';
  static const String _keyBrokerWebsite = 'broker_website';
  static const String _keyLastUpdated = 'broker_selection_last_updated';

  /// Save selected broker to SharedPreferences
  Future<void> saveSelectedBroker(BrokerCatalog catalog) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save basic info
      await prefs.setString(_keyBrokerId, catalog.catalogId);
      await prefs.setString(_keyBrokerName, catalog.catalogName);
      await prefs.setString(_keyLastUpdated, DateTime.now().toIso8601String());

      // Save country if available
      if (catalog.metadata?.country != null) {
        await prefs.setString(_keyBrokerCountry, catalog.metadata!.country);
      }

      // Save website if available
      if (catalog.metadata?.website != null) {
        await prefs.setString(_keyBrokerWebsite, catalog.metadata!.website);
      }

      // Save MT4 servers
      if (catalog.platforms.mt4.available) {
        if (catalog.platforms.mt4.liveServers.isNotEmpty) {
          await prefs.setString(
            _keyMT4Server,
            catalog.platforms.mt4.liveServers.first,
          );
        }

        if (catalog.platforms.mt4.demoServer != null) {
          await prefs.setString(
            _keyMT4DemoServer,
            catalog.platforms.mt4.demoServer!,
          );
        }
      }

      // Save MT5 servers
      if (catalog.platforms.mt5.available) {
        if (catalog.platforms.mt5.liveServers.isNotEmpty) {
          await prefs.setString(
            _keyMT5Server,
            catalog.platforms.mt5.liveServers.first,
          );
        }

        if (catalog.platforms.mt5.demoServer != null) {
          await prefs.setString(
            _keyMT5DemoServer,
            catalog.platforms.mt5.demoServer!,
          );
        }
      }

      // Set preferred platform (default to MT4 if both available)
      if (catalog.platforms.mt4.available) {
        await prefs.setString(_keyPreferredPlatform, 'MT4');
      } else if (catalog.platforms.mt5.available) {
        await prefs.setString(_keyPreferredPlatform, 'MT5');
      }

      debugPrint('✓ Saved broker settings: ${catalog.catalogName}');
    } catch (e) {
      debugPrint('✗ Error saving broker settings: $e');
      rethrow;
    }
  }

  /// Get selected broker ID
  Future<String?> getSelectedBrokerId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyBrokerId);
    } catch (e) {
      debugPrint('✗ Error getting broker ID: $e');
      return null;
    }
  }

  /// Get selected broker name
  Future<String?> getSelectedBrokerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyBrokerName);
    } catch (e) {
      debugPrint('✗ Error getting broker name: $e');
      return null;
    }
  }

  /// Get broker servers
  ///
  /// Returns map with MT4/MT5 server names
  Future<Map<String, String>> getBrokerServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final servers = <String, String>{};

      final mt4Server = prefs.getString(_keyMT4Server);
      if (mt4Server != null) {
        servers['mt4_live'] = mt4Server;
      }

      final mt4DemoServer = prefs.getString(_keyMT4DemoServer);
      if (mt4DemoServer != null) {
        servers['mt4_demo'] = mt4DemoServer;
      }

      final mt5Server = prefs.getString(_keyMT5Server);
      if (mt5Server != null) {
        servers['mt5_live'] = mt5Server;
      }

      final mt5DemoServer = prefs.getString(_keyMT5DemoServer);
      if (mt5DemoServer != null) {
        servers['mt5_demo'] = mt5DemoServer;
      }

      return servers;
    } catch (e) {
      debugPrint('✗ Error getting broker servers: $e');
      return {};
    }
  }

  /// Get preferred platform
  Future<String?> getPreferredPlatform() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyPreferredPlatform);
    } catch (e) {
      debugPrint('✗ Error getting preferred platform: $e');
      return null;
    }
  }

  /// Set preferred platform
  Future<void> setPreferredPlatform(String platform) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPreferredPlatform, platform);
      debugPrint('✓ Set preferred platform: $platform');
    } catch (e) {
      debugPrint('✗ Error setting preferred platform: $e');
      rethrow;
    }
  }

  /// Get broker country
  Future<String?> getBrokerCountry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyBrokerCountry);
    } catch (e) {
      debugPrint('✗ Error getting broker country: $e');
      return null;
    }
  }

  /// Get broker website
  Future<String?> getBrokerWebsite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyBrokerWebsite);
    } catch (e) {
      debugPrint('✗ Error getting broker website: $e');
      return null;
    }
  }

  /// Get last updated timestamp
  Future<DateTime?> getLastUpdated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_keyLastUpdated);

      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }

      return null;
    } catch (e) {
      debugPrint('✗ Error getting last updated: $e');
      return null;
    }
  }

  /// Clear selected broker
  Future<void> clearSelectedBroker() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyBrokerId);
      await prefs.remove(_keyBrokerName);
      await prefs.remove(_keyMT4Server);
      await prefs.remove(_keyMT5Server);
      await prefs.remove(_keyMT4DemoServer);
      await prefs.remove(_keyMT5DemoServer);
      await prefs.remove(_keyPreferredPlatform);
      await prefs.remove(_keyBrokerCountry);
      await prefs.remove(_keyBrokerWebsite);
      await prefs.remove(_keyLastUpdated);

      debugPrint('✓ Cleared broker selection');
    } catch (e) {
      debugPrint('✗ Error clearing broker selection: $e');
      rethrow;
    }
  }

  /// Check if a broker is currently selected
  Future<bool> hasSelectedBroker() async {
    final brokerId = await getSelectedBrokerId();
    return brokerId != null && brokerId.isNotEmpty;
  }

  /// Get all broker settings as map
  Future<Map<String, dynamic>> getAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'broker_id': prefs.getString(_keyBrokerId),
        'broker_name': prefs.getString(_keyBrokerName),
        'broker_country': prefs.getString(_keyBrokerCountry),
        'broker_website': prefs.getString(_keyBrokerWebsite),
        'mt4_server': prefs.getString(_keyMT4Server),
        'mt5_server': prefs.getString(_keyMT5Server),
        'mt4_demo_server': prefs.getString(_keyMT4DemoServer),
        'mt5_demo_server': prefs.getString(_keyMT5DemoServer),
        'preferred_platform': prefs.getString(_keyPreferredPlatform),
        'last_updated': prefs.getString(_keyLastUpdated),
      };
    } catch (e) {
      debugPrint('✗ Error getting all settings: $e');
      return {};
    }
  }

  /// Export settings for debugging
  Future<String> exportSettings() async {
    final settings = await getAllSettings();
    return settings.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
  }
}
