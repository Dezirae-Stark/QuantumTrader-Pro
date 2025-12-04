import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/colors/quantum_colors.dart';
import '../theme/components/quantum_button.dart';

class MarketPairDialog extends StatefulWidget {
  final List<String> currentPairs;
  final Function(List<String>) onPairsUpdated;

  const MarketPairDialog({
    super.key,
    required this.currentPairs,
    required this.onPairsUpdated,
  });

  @override
  State<MarketPairDialog> createState() => _MarketPairDialogState();
}

class _MarketPairDialogState extends State<MarketPairDialog> {
  late List<String> _selectedPairs;
  final TextEditingController _customPairController = TextEditingController();
  late Box _settingsBox;

  // Available market pairs
  final List<String> _availablePairs = [
    // Forex Major Pairs
    'EURUSD', 'GBPUSD', 'USDJPY', 'USDCHF', 'AUDUSD', 'USDCAD', 'NZDUSD',
    // Forex Minor Pairs
    'EURGBP', 'EURJPY', 'GBPJPY', 'AUDJPY', 'EURAUD', 'GBPAUD',
    // Metals
    'XAUUSD', 'XAGUSD',
    // Indices
    'US30', 'US100', 'US500', 'DE30', 'UK100',
    // Crypto
    'BTCUSD', 'ETHUSD', 'BNBUSD', 'XRPUSD',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPairs = List.from(widget.currentPairs);
    _initializeSettingsBox();
  }

  Future<void> _initializeSettingsBox() async {
    _settingsBox = await Hive.openBox('market_settings');
  }

  @override
  void dispose() {
    _customPairController.dispose();
    super.dispose();
  }

  void _togglePair(String pair) {
    setState(() {
      if (_selectedPairs.contains(pair)) {
        _selectedPairs.remove(pair);
      } else {
        _selectedPairs.add(pair);
      }
    });
  }

  void _addCustomPair() {
    final customPair = _customPairController.text.trim().toUpperCase();
    if (customPair.isNotEmpty && !_selectedPairs.contains(customPair)) {
      setState(() {
        _selectedPairs.add(customPair);
        if (!_availablePairs.contains(customPair)) {
          _availablePairs.add(customPair);
        }
      });
      _customPairController.clear();
    }
  }

  Future<void> _savePairs() async {
    await _settingsBox.put('watched_pairs', _selectedPairs);
    widget.onPairsUpdated(_selectedPairs);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: QuantumColors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: QuantumColors.neonCyan.withOpacity(0.3),
        ),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manage Market Pairs',
                  style: theme.textTheme.headlineSmall!.copyWith(
                    color: QuantumColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: QuantumColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedPairs.length} pairs selected',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: QuantumColors.neonCyan,
              ),
            ),
            const SizedBox(height: 24),

            // Custom pair input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customPairController,
                    style: TextStyle(color: QuantumColors.textPrimary),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Add custom pair (e.g., EURAUD)',
                      hintStyle: TextStyle(color: QuantumColors.textTertiary),
                      filled: true,
                      fillColor: QuantumColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: QuantumColors.neonCyan.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: QuantumColors.neonCyan,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addCustomPair(),
                  ),
                ),
                const SizedBox(width: 12),
                QuantumButton(
                  text: 'Add',
                  icon: Icons.add,
                  size: QuantumButtonSize.medium,
                  onPressed: _addCustomPair,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Market pairs grid
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availablePairs.map((pair) {
                    final isSelected = _selectedPairs.contains(pair);
                    return GestureDetector(
                      onTap: () => _togglePair(pair),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? QuantumColors.neonCyan.withOpacity(0.2)
                              : QuantumColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? QuantumColors.neonCyan
                                : QuantumColors.surface,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? QuantumColors.glowShadow(QuantumColors.neonCyan)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? QuantumColors.neonCyan
                                  : QuantumColors.textTertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pair,
                              style: TextStyle(
                                color: isSelected
                                    ? QuantumColors.neonCyan
                                    : QuantumColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                QuantumButton(
                  text: 'Cancel',
                  type: QuantumButtonType.outline,
                  size: QuantumButtonSize.medium,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                QuantumButton(
                  text: 'Save',
                  icon: Icons.save,
                  size: QuantumButtonSize.medium,
                  onPressed: _savePairs,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}