import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/broker_catalog_provider.dart';
import '../../widgets/broker/broker_card.dart';
import 'broker_details_screen.dart';
import 'broker_search_screen.dart';

/// Broker List Screen - Browse all available brokers
///
/// Features:
/// - Browse all brokers from catalogs
/// - Filter by platform (All, MT4, MT5)
/// - Pull-to-refresh for updates
/// - Navigate to details on tap
/// - Search functionality
class BrokerListScreen extends StatefulWidget {
  const BrokerListScreen({Key? key}) : super(key: key);

  @override
  State<BrokerListScreen> createState() => _BrokerListScreenState();
}

class _BrokerListScreenState extends State<BrokerListScreen> {
  @override
  void initState() {
    super.initState();
    // Load catalogs on screen open if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BrokerCatalogProvider>();
      if (provider.catalogCount == 0 && !provider.isLoading) {
        provider.loadCatalogs();
      }
    });
  }

  Future<void> _handleRefresh() async {
    final provider = context.read<BrokerCatalogProvider>();
    await provider.refreshCatalogs();
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BrokerSearchScreen(),
      ),
    );
  }

  void _navigateToBrokerDetails(String catalogId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrokerDetailsScreen(catalogId: catalogId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Broker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _navigateToSearch,
            tooltip: 'Search brokers',
          ),
        ],
      ),
      body: Consumer<BrokerCatalogProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (provider.isLoading && provider.catalogCount == 0) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading broker catalogs...'),
                  SizedBox(height: 8),
                  Text(
                    'This may take a few moments',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Error state
          if (provider.errorMessage != null && provider.catalogCount == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to Load Brokers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.loadCatalogs(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Empty state
          if (provider.catalogCount == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No Brokers Available',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please check your internet connection and try again',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          // Success state - show brokers
          final stats = provider.getStatistics();
          final catalogs = provider.catalogs;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: Column(
              children: [
                // Summary banner
                _BrokerSummaryBanner(stats: stats),

                // Filter chips
                _PlatformFilterChips(
                  currentFilter: provider.platformFilter,
                  onFilterChanged: provider.filterByPlatform,
                ),

                // Error message (if any, while showing cached data)
                if (provider.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange[800]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Using cached data: ${provider.errorMessage}',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: provider.clearError,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                // Broker list
                Expanded(
                  child: catalogs.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_list_off,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No Brokers Match Filter',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Try changing your filter settings',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: catalogs.length,
                          padding: const EdgeInsets.only(bottom: 16),
                          itemBuilder: (context, index) {
                            final catalog = catalogs[index];
                            final isSelected = provider.isBrokerSelected(
                              catalog.catalogId,
                            );

                            return BrokerCard(
                              catalog: catalog,
                              isSelected: isSelected,
                              onTap: () => _navigateToBrokerDetails(
                                catalog.catalogId,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Banner showing broker statistics
class _BrokerSummaryBanner extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _BrokerSummaryBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.1),
            theme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business,
                color: theme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats['total_brokers']} Brokers Available',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'All verified with Ed25519 signatures',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                label: 'MT4',
                count: stats['mt4_brokers'] as int,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'MT5',
                count: stats['mt5_brokers'] as int,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Both',
                count: stats['both_platforms'] as int,
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small chip showing platform statistics
class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chips for platform selection
class _PlatformFilterChips extends StatelessWidget {
  final String currentFilter;
  final void Function(String) onFilterChanged;

  const _PlatformFilterChips({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 20),
          const SizedBox(width: 12),
          _FilterChip(
            label: 'All Brokers',
            isSelected: currentFilter == 'all',
            onTap: () => onFilterChanged('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'MT4 Only',
            isSelected: currentFilter == 'mt4',
            onTap: () => onFilterChanged('mt4'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'MT5 Only',
            isSelected: currentFilter == 'mt5',
            onTap: () => onFilterChanged('mt5'),
          ),
        ],
      ),
    );
  }
}

/// Individual filter chip
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor
              : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
