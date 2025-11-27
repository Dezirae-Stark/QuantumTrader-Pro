class RiskAssessment {
  final bool isApproved;
  final String? reason;
  final double recommendedLotSize;
  final double? stopLoss;
  final double? takeProfit;
  final double riskRewardRatio;
  final double maxDrawdown;

  RiskAssessment({
    required this.isApproved,
    this.reason,
    required this.recommendedLotSize,
    this.stopLoss,
    this.takeProfit,
    this.riskRewardRatio = 2.0,
    this.maxDrawdown = 0.2,
  });
}