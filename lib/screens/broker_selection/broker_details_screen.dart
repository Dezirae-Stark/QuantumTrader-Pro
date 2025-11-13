import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/catalog/broker_catalog.dart';
import '../../providers/broker_catalog_provider.dart';
import '../../widgets/broker/platform_badge.dart';

/// Broker Details Screen - View complete broker information
///
/// Features:
/// - Complete broker details
/// - MT4/MT5 platform information with servers
/// - Trading conditions and fees
/// - Account types
/// - Contact information
/// - "Select This Broker" button
class BrokerDetailsScreen extends StatelessWidget {
  final String catalogId;

  const BrokerDetailsScreen({
    Key? key,
    required this.catalogId,
  }) : super(key: key);

  Future<void> _selectBroker(BuildContext context, BrokerCatalog catalog) async {
    final provider = context.read<BrokerCatalogProvider>();

    try {
      await provider.selectBroker(catalog);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Selected ${catalog.catalogName}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate back to previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Failed to select broker: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BrokerCatalogProvider>(
      builder: (context, provider, child) {
        final catalog = provider.getCatalogById(catalogId);

        if (catalog == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Broker Details')),
            body: const Center(
              child: Text('Broker not found'),
            ),
          );
        }

        final isSelected = provider.isBrokerSelected(catalogId);

        return Scaffold(
          appBar: AppBar(
            title: Text(catalog.catalogName),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Implement share functionality
                },
                tooltip: 'Share broker info',
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                _BrokerHeader(
                  catalog: catalog,
                  isSelected: isSelected,
                ),

                // Select broker button (if not selected)
                if (!isSelected)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _selectBroker(context, catalog),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Select This Broker'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),

                // Already selected indicator
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Currently Selected Broker',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 1),

                // Platforms section
                _PlatformsSection(
                  catalog: catalog,
                  onCopy: (text, label) => _copyToClipboard(context, text, label),
                ),

                const Divider(height: 1),

                // Trading conditions section
                if (catalog.features != null || catalog.tradingConditions != null)
                  _TradingConditionsSection(catalog: catalog),

                const Divider(height: 1),

                // Account types section
                if (catalog.accountTypes != null && catalog.accountTypes!.isNotEmpty)
                  _AccountTypesSection(catalog: catalog),

                const Divider(height: 1),

                // Contact section
                if (catalog.contact != null || catalog.metadata?.website != null)
                  _ContactSection(catalog: catalog),

                // Disclaimer
                if (catalog.disclaimer != null)
                  _DisclaimerSection(disclaimer: catalog.disclaimer!),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Broker header with name, country, and basic info
class _BrokerHeader extends StatelessWidget {
  final BrokerCatalog catalog;
  final bool isSelected;

  const _BrokerHeader({
    required this.catalog,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor.withOpacity(0.1),
            theme.primaryColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        children: [
          // Broker icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business,
              size: 40,
              color: theme.primaryColor,
            ),
          ),

          const SizedBox(height: 16),

          // Broker name
          Text(
            catalog.catalogName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Country and regulation
          if (catalog.metadata?.country != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.public,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  catalog.metadata!.country,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (catalog.metadata!.regulatoryBodies?.isNotEmpty == true) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.verified_user,
                    size: 18,
                    color: Colors.green[700],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Regulated',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Platforms section showing MT4/MT5 availability and servers
class _PlatformsSection extends StatelessWidget {
  final BrokerCatalog catalog;
  final void Function(String, String) onCopy;

  const _PlatformsSection({
    required this.catalog,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Trading Platforms',
      icon: Icons.show_chart,
      child: Column(
        children: [
          // MT4
          if (catalog.platforms.mt4.available) ...[
            _PlatformCard(
              platform: 'MT4',
              liveServers: catalog.platforms.mt4.liveServers,
              demoServer: catalog.platforms.mt4.demoServer,
              onCopy: onCopy,
            ),
            const SizedBox(height: 12),
          ],

          // MT5
          if (catalog.platforms.mt5.available)
            _PlatformCard(
              platform: 'MT5',
              liveServers: catalog.platforms.mt5.liveServers,
              demoServer: catalog.platforms.mt5.demoServer,
              onCopy: onCopy,
            ),

          // Neither available (shouldn't happen, but handle it)
          if (!catalog.platforms.mt4.available && !catalog.platforms.mt5.available)
            const Text('No trading platforms available'),
        ],
      ),
    );
  }
}

/// Platform card showing server details
class _PlatformCard extends StatelessWidget {
  final String platform;
  final List<String> liveServers;
  final String? demoServer;
  final void Function(String, String) onCopy;

  const _PlatformCard({
    required this.platform,
    required this.liveServers,
    this.demoServer,
    required this.onCopy,
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
              ...liveServers.map((server) => _ServerRow(
                    server: server,
                    isDemo: false,
                    onCopy: () => onCopy(server, 'live server'),
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
              _ServerRow(
                server: demoServer!,
                isDemo: true,
                onCopy: () => onCopy(demoServer!, 'demo server'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Server row with copy button
class _ServerRow extends StatelessWidget {
  final String server;
  final bool isDemo;
  final VoidCallback onCopy;

  const _ServerRow({
    required this.server,
    required this.isDemo,
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
        border: Border.all(
          color: isDemo
              ? Colors.orange[200]!
              : theme.colorScheme.outline.withOpacity(0.3),
        ),
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

/// Trading conditions section
class _TradingConditionsSection extends StatelessWidget {
  final BrokerCatalog catalog;

  const _TradingConditionsSection({required this.catalog});

  @override
  Widget build(BuildContext context) {
    final features = catalog.features;
    final conditions = catalog.tradingConditions;

    return _Section(
      title: 'Trading Conditions',
      icon: Icons.attach_money,
      child: Column(
        children: [
          if (features?.minDeposit != null)
            _InfoRow(
              label: 'Minimum Deposit',
              value: '\$${features!.minDeposit}',
            ),
          if (features?.maxLeverage != null)
            _InfoRow(
              label: 'Maximum Leverage',
              value: '1:${features!.maxLeverage}',
            ),
          if (features?.spreads != null)
            _InfoRow(
              label: 'Spreads',
              value: 'From ${features!.spreads!.from} pips (${features!.spreads!.type})',
            ),
          if (conditions?.commission != null)
            _InfoRow(
              label: 'Commission',
              value: conditions!.commission!,
            ),
          if (conditions?.swapFree == true)
            _InfoRow(
              label: 'Islamic Account',
              value: 'Available (Swap-free)',
              valueColor: Colors.green,
            ),
          if (conditions?.microLots == true)
            _InfoRow(
              label: 'Micro Lots',
              value: 'Supported',
            ),
          if (conditions?.hedging == true)
            _InfoRow(
              label: 'Hedging',
              value: 'Allowed',
            ),
          if (conditions?.scalping == true)
            _InfoRow(
              label: 'Scalping',
              value: 'Allowed',
            ),
          if (conditions?.eaAllowed == true)
            _InfoRow(
              label: 'Expert Advisors',
              value: 'Allowed',
            ),
        ],
      ),
    );
  }
}

/// Account types section
class _AccountTypesSection extends StatelessWidget {
  final BrokerCatalog catalog;

  const _AccountTypesSection({required this.catalog});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Account Types',
      icon: Icons.account_balance_wallet,
      child: Column(
        children: catalog.accountTypes!.map((accountType) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(
                accountType.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (accountType.minDeposit != null)
                    Text('Min Deposit: \$${accountType.minDeposit}'),
                  if (accountType.spreads != null)
                    Text('Spreads: ${accountType.spreads}'),
                  if (accountType.commission != null)
                    Text('Commission: ${accountType.commission}'),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Contact section
class _ContactSection extends StatelessWidget {
  final BrokerCatalog catalog;

  const _ContactSection({required this.catalog});

  @override
  Widget build(BuildContext context) {
    final contact = catalog.contact;
    final metadata = catalog.metadata;

    return _Section(
      title: 'Contact Information',
      icon: Icons.contact_mail,
      child: Column(
        children: [
          if (metadata?.website != null)
            _InfoRow(
              label: 'Website',
              value: metadata!.website,
              icon: Icons.language,
            ),
          if (contact?.email != null)
            _InfoRow(
              label: 'Email',
              value: contact!.email!,
              icon: Icons.email,
            ),
          if (contact?.phone != null)
            _InfoRow(
              label: 'Phone',
              value: contact!.phone!,
              icon: Icons.phone,
            ),
          if (contact?.liveChat == true)
            _InfoRow(
              label: 'Live Chat',
              value: 'Available',
              icon: Icons.chat,
              valueColor: Colors.green,
            ),
        ],
      ),
    );
  }
}

/// Disclaimer section
class _DisclaimerSection extends StatelessWidget {
  final String disclaimer;

  const _DisclaimerSection({required this.disclaimer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                'Disclaimer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            disclaimer,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable section widget
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.primaryColor),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Info row widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
