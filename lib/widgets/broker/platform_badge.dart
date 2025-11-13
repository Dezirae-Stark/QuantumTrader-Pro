import 'package:flutter/material.dart';

/// Badge widget for displaying MT4/MT5 platform availability
///
/// Shows colored badges for MT4 and MT5 platforms with
/// appropriate styling and colors.
class PlatformBadge extends StatelessWidget {
  final String platform;
  final bool isSmall;

  const PlatformBadge({
    Key? key,
    required this.platform,
    this.isSmall = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Colors for different platforms
    final backgroundColor = platform == 'MT4'
        ? Colors.blue[100]!
        : Colors.green[100]!;

    final textColor = platform == 'MT4'
        ? Colors.blue[800]!
        : Colors.green[800]!;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: isSmall ? 12 : 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            platform,
            style: TextStyle(
              color: textColor,
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Extended platform badge with server information
class PlatformBadgeWithServer extends StatelessWidget {
  final String platform;
  final String? serverName;
  final bool isDemoServer;

  const PlatformBadgeWithServer({
    Key? key,
    required this.platform,
    this.serverName,
    this.isDemoServer = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform header
            Row(
              children: [
                PlatformBadge(platform: platform),
                const Spacer(),
                if (isDemoServer)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DEMO',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            // Server name
            if (serverName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.dns,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          serverName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      // Copy server name to clipboard
                      // TODO: Implement clipboard copy
                    },
                    tooltip: 'Copy server name',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
