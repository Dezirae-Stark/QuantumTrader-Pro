import 'dart:async';
import 'package:logger/logger.dart';
import 'package:hive/hive.dart';

class TelegramService {
  final Logger _logger = Logger();
  bool _isInitialized = false;
  String? _botToken;
  String? _chatId;
  StreamController<TelegramCommand>? _commandStream;

  Stream<TelegramCommand> get commandStream =>
      _commandStream?.stream ?? Stream.empty();

  Future<void> initialize() async {
    _logger.i('Initializing Telegram Service...');

    final settingsBox = await Hive.openBox('settings');
    _botToken = settingsBox.get('telegram_bot_token');
    _chatId = settingsBox.get('telegram_chat_id');

    if (_botToken != null && _chatId != null) {
      _commandStream = StreamController<TelegramCommand>.broadcast();
      _startListening();
      _isInitialized = true;
      _logger.i('Telegram service initialized successfully');
    } else {
      _logger.w('Telegram credentials not configured');
    }
  }

  void setCredentials(String botToken, String chatId) async {
    _botToken = botToken;
    _chatId = chatId;

    final settingsBox = await Hive.openBox('settings');
    await settingsBox.put('telegram_bot_token', botToken);
    await settingsBox.put('telegram_chat_id', chatId);

    if (!_isInitialized) {
      await initialize();
    }
  }

  void _startListening() {
    // Simulated Telegram command listener
    // In production, this would use the Televerse package to listen for bot commands
    _logger.i('Started listening for Telegram commands');
  }

  Future<bool> sendNotification(String message, {bool urgent = false}) async {
    if (_botToken == null || _chatId == null) {
      _logger.w('Cannot send notification: Telegram not configured');
      return false;
    }

    try {
      // Simulate sending notification
      _logger.i('Telegram notification sent: $message');

      // In production, implement actual Telegram API call:
      // final bot = Bot(_botToken!);
      // await bot.sendMessage(ChatID(_chatId!), message);

      return true;
    } catch (e) {
      _logger.e('Error sending Telegram notification: $e');
      return false;
    }
  }

  Future<bool> sendTradeAlert({
    required String symbol,
    required String action,
    required double price,
    String? reason,
  }) async {
    final message =
        '''
🚨 *Trade Alert*

Symbol: $symbol
Action: ${action.toUpperCase()}
Price: $price
${reason != null ? 'Reason: $reason' : ''}

React with ✅ to approve or ❌ to deny
''';

    return await sendNotification(message, urgent: true);
  }

  Future<bool> sendPnLUpdate(
    double totalPnL,
    List<String> topPerformers,
  ) async {
    final emoji = totalPnL >= 0 ? '📈' : '📉';
    final message =
        '''
$emoji *P&L Update*

Total P&L: \$${totalPnL.toStringAsFixed(2)}

Top Performers:
${topPerformers.map((p) => '• $p').join('\n')}
''';

    return await sendNotification(message);
  }

  Future<bool> requestTradeApproval({
    required String symbol,
    required String type,
    required double volume,
  }) async {
    final message =
        '''
🤔 *Trade Approval Requested*

Symbol: $symbol
Type: $type
Volume: $volume

Reply with /approve or /deny
''';

    return await sendNotification(message, urgent: true);
  }

  void dispose() {
    _commandStream?.close();
  }
}

class TelegramCommand {
  final String command;
  final List<String> arguments;
  final DateTime timestamp;

  TelegramCommand({
    required this.command,
    this.arguments = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
