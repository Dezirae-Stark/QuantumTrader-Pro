import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/broker_catalog_provider.dart';
import '../../widgets/broker/broker_card.dart';
import 'broker_details_screen.dart';

/// Broker Search Screen - Search and filter brokers
///
/// Features:
/// - Real-time search as you type
/// - Search by: name, country, currencies, instruments
/// - Quick filter chips
/// - Search results with highlighting
class BrokerSearchScreen extends StatefulWidget {
  const BrokerSearchScreen({Key? key}) : super(key: key);

  @override
  State<BrokerSearchScreen> createState() => _BrokerSearchScreenState();
}

class _BrokerSearchScreenState extends State<BrokerSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final provider = context.read<BrokerCatalogProvider>();

    setState(() {
      _hasSearched = query.isNotEmpty;
    });

    provider.searchBrokers(query);
  }

  void _clearSearch() {
    _searchController.clear();
    final provider = context.read<BrokerCatalogProvider>();
    provider.searchBrokers('');

    setState(() {
      _hasSearched = false;
    });
  }

  void _applyQuickFilter(String filter) {
    _searchController.text = filter;
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search brokers...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: theme.colorScheme.onPrimary.withOpacity(0.7),
            ),
          ),
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontSize: 18,
          ),
          cursorColor: theme.colorScheme.onPrimary,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
              tooltip: 'Clear search',
            ),
        ],
      ),
      body: Consumer<BrokerCatalogProvider>(
        builder: (context, provider, child) {
          final catalogs = provider.catalogs;

          return Column(
            children: [
              // Quick filters (shown when no search)
              if (!_hasSearched && provider.searchQuery.isEmpty)
                _QuickFiltersSection(
                  onFilterTap: _applyQuickFilter,
                ),

              // Search results count
              if (_hasSearched)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${catalogs.length} ${catalogs.length == 1 ? 'result' : 'results'} found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Results or empty state
              Expanded(
                child: _hasSearched
                    ? catalogs.isEmpty
                        ? _NoResultsView(
                            query: _searchController.text,
                            onClearSearch: _clearSearch,
                          )
                        : ListView.builder(
                            itemCount: catalogs.length,
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
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
                          )
                    : _SearchSuggestionsView(
                        onSuggestionTap: _applyQuickFilter,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Quick filters section (shown when no search)
class _QuickFiltersSection extends StatelessWidget {
  final void Function(String) onFilterTap;

  const _QuickFiltersSection({required this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Searches',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickFilterChip(
                label: 'Low Spread',
                icon: Icons.speed,
                onTap: () => onFilterTap('low spread'),
              ),
              _QuickFilterChip(
                label: 'Islamic Account',
                icon: Icons.mosque,
                onTap: () => onFilterTap('swap free'),
              ),
              _QuickFilterChip(
                label: 'High Leverage',
                icon: Icons.trending_up,
                onTap: () => onFilterTap('500'),
              ),
              _QuickFilterChip(
                label: 'No Commission',
                icon: Icons.money_off,
                onTap: () => onFilterTap('no commission'),
              ),
              _QuickFilterChip(
                label: 'Scalping Allowed',
                icon: Icons.flash_on,
                onTap: () => onFilterTap('scalping'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Quick filter chip
class _QuickFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search suggestions view (shown when not searched)
class _SearchSuggestionsView extends StatelessWidget {
  final void Function(String) onSuggestionTap;

  const _SearchSuggestionsView({required this.onSuggestionTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 32),

        // Search tips icon
        Center(
          child: Icon(
            Icons.search,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
        ),

        const SizedBox(height: 24),

        // Title
        Text(
          'Search for Brokers',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // Description
        Text(
          'Find brokers by name, country, or features',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Search examples
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Examples:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _SearchExample(
                  icon: Icons.business,
                  text: 'Broker name (e.g., "Sample Broker")',
                ),
                const SizedBox(height: 8),
                _SearchExample(
                  icon: Icons.public,
                  text: 'Country (e.g., "United States")',
                ),
                const SizedBox(height: 8),
                _SearchExample(
                  icon: Icons.attach_money,
                  text: 'Currency (e.g., "EUR", "GBP")',
                ),
                const SizedBox(height: 8),
                _SearchExample(
                  icon: Icons.show_chart,
                  text: 'Features (e.g., "low spread", "scalping")',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Search tips
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Search Tips',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SearchTip(text: 'Search is case-insensitive'),
                _SearchTip(text: 'Results update as you type'),
                _SearchTip(text: 'Use quick filters for common searches'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Search example row
class _SearchExample extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SearchExample({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Search tip row
class _SearchTip extends StatelessWidget {
  final String text;

  const _SearchTip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// No results view
class _NoResultsView extends StatelessWidget {
  final String query;
  final VoidCallback onClearSearch;

  const _NoResultsView({
    required this.query,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Brokers Found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No brokers match "$query"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
            ),
            const SizedBox(height: 16),
            Text(
              'Try searching for:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Broker name\n'
              '• Country\n'
              '• Currency (EUR, USD, GBP)\n'
              '• Features (scalping, swap-free)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
