import 'package:flutter/material.dart';
import '../../models/catalog/broker_catalog.dart';
import 'platform_badge.dart';

/// Reusable card widget for displaying broker information
///
/// Used in broker list views to show:
/// - Broker name
/// - Country
/// - Platform availability (MT4/MT5)
/// - Quick info (min deposit, leverage)
class BrokerCard extends StatelessWidget {
  final BrokerCatalog catalog;
  final VoidCallback? onTap;
  final bool isSelected;

  const BrokerCard({
    Key? key,
    required this.catalog,
    this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 4 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Name and selection indicator
              Row(
                children: [
                  // Broker icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.business,
                      color: theme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Broker name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          catalog.catalogName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (catalog.metadata?.country != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.public,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                catalog.metadata!.country,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Selection indicator
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Platform badges
              Row(
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  if (catalog.platforms.mt4.available)
                    const PlatformBadge(platform: 'MT4'),
                  if (catalog.platforms.mt4.available &&
                      catalog.platforms.mt5.available)
                    const SizedBox(width: 8),
                  if (catalog.platforms.mt5.available)
                    const PlatformBadge(platform: 'MT5'),
                ],
              ),

              const SizedBox(height: 12),

              // Quick info row
              if (catalog.features != null) ...[
                Row(
                  children: [
                    // Min deposit
                    if (catalog.features!.minDeposit != null) ...[
                      Icon(
                        Icons.attach_money,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Min: \$${catalog.features!.minDeposit}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],

                    if (catalog.features!.minDeposit != null &&
                        catalog.features!.maxLeverage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '•',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                    // Max leverage
                    if (catalog.features!.maxLeverage != null) ...[
                      Icon(
                        Icons.trending_up,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Leverage: 1:${catalog.features!.maxLeverage}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // Spreads info
              if (catalog.features?.spreads != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Spreads: From ${catalog.features!.spreads!.from} pips',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],

              // Tap hint
              if (onTap != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap for details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: theme.primaryColor,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
