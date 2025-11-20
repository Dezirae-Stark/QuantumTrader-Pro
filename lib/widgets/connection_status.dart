import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusDot(appState.isConnectedToMT4, 'MT4', Colors.blue),
        const SizedBox(width: 8),
        _buildStatusDot(appState.isTelegramConnected, 'TG', Colors.cyan),
      ],
    );
  }

  Widget _buildStatusDot(bool isConnected, String label, Color color) {
    return Tooltip(
      message: '$label ${isConnected ? 'Connected' : 'Disconnected'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isConnected ? color : Colors.grey).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isConnected ? color : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isConnected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
