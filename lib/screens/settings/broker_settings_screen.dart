import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/broker_catalog_provider.dart';
import '../../widgets/broker/platform_badge.dart';
import '../broker_selection/broker_list_screen.dart';
import '../broker_selection/broker_details_screen.dart';

/// Broker Settings Screen - Manage selected broker
///
/// Features:
/// - Display currently selected broker
/// - Show broker's MT4/MT5 servers
/// - Change broker button
/// - Clear selection
/// - Export settings for debugging
class BrokerSettingsScreen extends StatelessWidget {
  const BrokerSettingsScreen({Key? key}) : super(key: key);

  Future<void> _changeBroker(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BrokerListScreen(),
      ),
    );
  }

  Future<void> _clearSelection(BuildContext context) async {
    final provider = context.read<BrokerCatalogProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Broker Selection?'),
        content: const Text(
          'This will remove your current broker selection. '
          'You can select a new broker anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await provider.clearSelection();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Broker selection cleared'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✗ Failed to clear selection: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _viewBrokerDetails(BuildContext context, String catalogId) {
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
        title: const Text('Broker Settings'),
      ),
      body: Consumer<BrokerCatalogProvider>(
        builder: (context, provider, child) {
          final selectedBroker = provider.selectedBroker;

          if (selectedBroker == null) {
            return _NoSelectionView(
              onSelectBroker: () => _changeBroker(context),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected broker card
                _SelectedBrokerCard(
                  catalog: selectedBroker,
                  onViewDetails: () => _viewBrokerDetails(
                    context,
                    selectedBroker.catalogId,
                  ),
                  onChangeBroker: () => _changeBroker(context),
                ),

                const Divider(height: 1),

                // MT4/MT5 Configuration Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trading Platforms',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // MT4 section
                      if (selectedBroker.platforms.mt4.available) ...[
                        _PlatformConfigSection(
                          platform: 'MT4',
                          liveServers: selectedBroker.platforms.mt4.liveServers,
                          demoServer: selectedBroker.platforms.mt4.demoServer,
                          onCopyServer: (server) => _copyToClipboard(
                            context,
                            server,
                            'server',
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // MT5 section
                      if (selectedBroker.platforms.mt5.available)
                        _PlatformConfigSection(
                          platform: 'MT5',
                          liveServers: selectedBroker.platforms.mt5.liveServers,
                          demoServer: selectedBroker.platforms.mt5.demoServer,
                          onCopyServer: (server) => _copyToClipboard(
                            context,
                            server,
                            'server',
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Configuration instructions
                _ConfigurationInstructions(),

                const Divider(height: 1),

                // Actions section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Actions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: () => _changeBroker(context),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Change Broker'),
                      ),

                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed: () => _clearSelection(context),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Selection'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
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

/// Selected broker card
class _SelectedBrokerCard extends StatelessWidget {
  final dynamic catalog; // BrokerCatalog
  final VoidCallback onViewDetails;
  final VoidCallback onChangeBroker;

  const _SelectedBrokerCard({
    required this.catalog,
    required this.onViewDetails,
    required this.onChangeBroker,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.business,
                      color: theme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Broker',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          catalog.catalogName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Country
              if (catalog.metadata?.country != null)
                Row(
                  children: [
                    Icon(
                      Icons.public,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      catalog.metadata!.country,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // Platform badges
              Row(
                children: [
                  if (catalog.platforms.mt4.available)
                    const PlatformBadge(platform: 'MT4'),
                  if (catalog.platforms.mt4.available &&
                      catalog.platforms.mt5.available)
                    const SizedBox(width: 8),
                  if (catalog.platforms.mt5.available)
                    const PlatformBadge(platform: 'MT5'),
                ],
              ),

              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewDetails,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onChangeBroker,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Change'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Platform configuration section
class _PlatformConfigSection extends StatelessWidget {
  final String platform;
  final List<String> liveServers;
  final String? demoServer;
  final void Function(String) onCopyServer;

  const _PlatformConfigSection({
    required this.platform,
    required this.liveServers,
    this.demoServer,
    required this.onCopyServer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlatformBadge(platform: platform),
            const SizedBox(height: 16),

            // Live servers
            if (liveServers.isNotEmpty) ...[
              Text(
                'Live Server${liveServers.length > 1 ? 's' : ''}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...liveServers.map((server) => _ServerTile(
                    server: server,
                    onCopy: () => onCopyServer(server),
                  )),
            ],

            // Demo server
            if (demoServer != null) ...[
              const SizedBox(height: 12),
              Text(
                'Demo Server',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _ServerTile(
                server: demoServer!,
                isDemo: true,
                onCopy: () => onCopyServer(demoServer!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Server tile with copy button
class _ServerTile extends StatelessWidget {
  final String server;
  final bool isDemo;
  final VoidCallback onCopy;

  const _ServerTile({
    required this.server,
    this.isDemo = false,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDemo
            ? Colors.orange[50]
            : theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.dns,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              server,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: onCopy,
            tooltip: 'Copy server name',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Configuration instructions
class _ConfigurationInstructions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.blue[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Text(
                    'Configuration Instructions',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InstructionStep(
                number: 1,
                text: 'Open MT4/MT5 terminal',
              ),
              _InstructionStep(
                number: 2,
                text: 'Go to File → Login to Trade Account',
              ),
              _InstructionStep(
                number: 3,
                text: 'Enter your login credentials',
              ),
              _InstructionStep(
                number: 4,
                text: 'Select the server shown above',
              ),
              _InstructionStep(
                number: 5,
                text: 'Configure the bridge server in Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Instruction step
class _InstructionStep extends StatelessWidget {
  final int number;
  final String text;

  const _InstructionStep({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue[700],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// No selection view (shown when no broker selected)
class _NoSelectionView extends StatelessWidget {
  final VoidCallback onSelectBroker;

  const _NoSelectionView({required this.onSelectBroker});

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
              Icons.business_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Broker Selected',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a broker to start trading',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onSelectBroker,
              icon: const Icon(Icons.add),
              label: const Text('Select Broker'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
