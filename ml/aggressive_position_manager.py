#!/usr/bin/env python3
"""
Aggressive Position Manager - 100:1+ Leverage with 20% Risk Model
Designed for high-leverage news trading targeting 10%+ daily returns
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import logging

from news_event_trading_suite import NewsSignal, NewsEventType, NewsStrategy

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class HighLeveragePosition:
    """High leverage position configuration"""
    symbol: str
    direction: str  # 'BUY' or 'SELL'
    entry_price: float
    position_size_lots: float  # Actual lot size (e.g., 10.0 lots)
    position_value_usd: float  # Total position value
    leverage_used: float  # Actual leverage (e.g., 150:1)
    risk_amount: float  # Dollar amount at risk
    risk_percentage: float  # Percentage of account at risk
    stop_loss: float
    take_profit_targets: List[float]
    target_profit_amounts: List[float]  # Dollar amounts for each target
    expected_daily_return: float  # Expected % return for the day
    
    
class AggressiveRiskLevel(Enum):
    """Risk levels for different news events"""
    MAXIMUM = "maximum"      # 20% risk - major events like FOMC
    HIGH = "high"           # 15% risk - high impact like NFP, BOE
    ELEVATED = "elevated"   # 12% risk - medium impact like ECB
    MODERATE = "moderate"   # 8% risk - lower impact events


class AggressivePositionManager:
    """
    Position manager optimized for 100:1+ leverage and 20% risk model
    
    Key Principles:
    - Maximum 20% account risk per trade
    - 100:1 to 300:1 leverage utilization
    - Target 10%+ daily returns
    - Aggressive profit targets on news volatility
    - Quick entries/exits during news spikes
    """
    
    def __init__(self, account_balance: float = 10000):
        self.account_balance = account_balance
        self.default_risk_percentage = 0.20  # 20% default risk for ALL GBP/USD trades
        self.target_daily_return = 0.10       # 10% daily target
        
        # Leverage settings
        self.max_leverage = 300  # Maximum leverage to use
        self.min_leverage = 100  # Minimum leverage for efficiency
        
        # Risk allocation - 20% for ALL GBP/USD trades (your standard approach)
        self.symbol_risk_allocation = {
            'GBPUSD': 0.20,  # 20% for ALL GBP/USD trades
            'EURUSD': 0.15,  # 15% for other major pairs
            'USDJPY': 0.15,  # 15% for other major pairs
            'DEFAULT': 0.10  # 10% for other symbols
        }
        
        # News events get additional profit scaling (not risk scaling)
        self.news_profit_multipliers = {
            NewsEventType.FOMC_RATE: 2.5,    # 2.5x profit targets during FOMC
            NewsEventType.BOE_RATE: 2.0,     # 2x for direct GBP impact
            NewsEventType.NFP: 1.8,          # 1.8x for major USD news
            NewsEventType.ECB_RATE: 1.5,     # 1.5x for EUR impact
        }
        
        # Lot size calculation (standard lot = 100,000 units)
        self.standard_lot_size = 100000
        
        # Profit scaling factors for news events
        self.profit_multipliers = {
            NewsEventType.FOMC_RATE: 3.0,    # 3x normal profit target
            NewsEventType.BOE_RATE: 2.5,     # 2.5x for direct GBP impact
            NewsEventType.NFP: 2.0,          # 2x for major USD news
            NewsEventType.ECB_RATE: 1.5,     # 1.5x for EUR impact
        }
    
    def calculate_aggressive_position(self, signal_data: dict, symbol: str = 'GBPUSD',
                                    spread: float = 0.0001, is_news_trade: bool = False) -> HighLeveragePosition:
        """
        Calculate aggressive position sizing for ANY GBP/USD trade (your 20% standard)
        """
        # Get risk percentage for this symbol (20% for GBP/USD)
        risk_percentage = self.symbol_risk_allocation.get(symbol, self.symbol_risk_allocation['DEFAULT'])
        risk_amount = self.account_balance * risk_percentage
        
        # Extract signal data
        entry_price = signal_data.get('entry_price', 1.27)
        stop_loss = signal_data.get('stop_loss', entry_price * 0.995)  # Default 0.5% stop
        direction = signal_data.get('direction', 'BUY')
        
        # Calculate stop distance
        stop_distance = abs(entry_price - stop_loss)
        
        # Calculate position size in lots
        # Risk = Lot Size * Stop Distance * Pip Value
        # For GBP/USD: Pip value = 10 USD per lot per pip (assuming 0.0001 pip size)
        pip_value = 10.0  # USD per lot per pip for GBP/USD
        stop_distance_pips = stop_distance / 0.0001
        
        # Position size = Risk Amount / (Stop Distance in Pips * Pip Value)
        position_size_lots = risk_amount / (stop_distance_pips * pip_value)
        
        # Calculate position value and leverage
        position_value = position_size_lots * self.standard_lot_size * news_signal.entry_price
        leverage_used = position_value / self.account_balance
        
        # Ensure leverage is within bounds
        if leverage_used > self.max_leverage:
            # Scale down position to fit max leverage
            leverage_used = self.max_leverage
            position_value = self.account_balance * leverage_used
            position_size_lots = position_value / (self.standard_lot_size * news_signal.entry_price)
            risk_amount = position_size_lots * stop_distance_pips * pip_value
            risk_percentage = risk_amount / self.account_balance
        
        # Calculate profit targets
        profit_targets = self._calculate_profit_targets(
            entry_price, direction, position_size_lots, pip_value, 
            signal_data, is_news_trade
        )
        
        # Calculate expected daily return
        expected_daily_return = self._calculate_expected_daily_return_flexible(
            profit_targets, leverage_used, risk_percentage
        )
        
        return HighLeveragePosition(
            symbol=symbol,
            direction=direction,
            entry_price=entry_price,
            position_size_lots=position_size_lots,
            position_value_usd=position_value,
            leverage_used=leverage_used,
            risk_amount=risk_amount,
            risk_percentage=risk_percentage,
            stop_loss=stop_loss,
            take_profit_targets=profit_targets['prices'],
            target_profit_amounts=profit_targets['amounts'],
            expected_daily_return=expected_daily_return
        )
    
    def _get_risk_percentage(self, risk_level: AggressiveRiskLevel) -> float:
        """Get risk percentage for different risk levels"""
        risk_map = {
            AggressiveRiskLevel.MAXIMUM: 0.20,    # 20%
            AggressiveRiskLevel.HIGH: 0.15,       # 15%
            AggressiveRiskLevel.ELEVATED: 0.12,   # 12%
            AggressiveRiskLevel.MODERATE: 0.08    # 8%
        }
        return risk_map[risk_level]
    
    def _calculate_aggressive_targets(self, news_signal: NewsSignal, 
                                    position_size_lots: float, 
                                    pip_value: float) -> Dict:
        """Calculate aggressive profit targets for high leverage trading"""
        # Get profit multiplier for this event
        multiplier = self.profit_multipliers.get(
            news_signal.event.event_type, 1.0
        )
        
        # Base targets from news signal
        base_targets = [
            news_signal.take_profit_1,
            news_signal.take_profit_2,
            news_signal.take_profit_3
        ]
        
        # Aggressive target calculation
        entry_price = news_signal.entry_price
        
        if news_signal.direction.name == 'BUY':
            # For BUY positions, extend targets higher
            aggressive_targets = [
                base_targets[0] * (1 + 0.0005 * multiplier),  # Extend first target
                base_targets[1] * (1 + 0.0010 * multiplier),  # Extend second target
                base_targets[2] * (1 + 0.0015 * multiplier),  # Extend third target
                entry_price * (1 + 0.0030 * multiplier)       # Add fourth aggressive target
            ]
        else:
            # For SELL positions, extend targets lower
            aggressive_targets = [
                base_targets[0] * (1 - 0.0005 * multiplier),  # Extend first target
                base_targets[1] * (1 - 0.0010 * multiplier),  # Extend second target
                base_targets[2] * (1 - 0.0015 * multiplier),  # Extend third target
                entry_price * (1 - 0.0030 * multiplier)       # Add fourth aggressive target
            ]
        
        # Calculate profit amounts for each target
        profit_amounts = []
        for target_price in aggressive_targets:
            if news_signal.direction.name == 'BUY':
                pips_profit = (target_price - entry_price) / 0.0001
            else:
                pips_profit = (entry_price - target_price) / 0.0001
            
            profit_amount = position_size_lots * pips_profit * pip_value
            profit_amounts.append(profit_amount)
        
        return {
            'prices': aggressive_targets,
            'amounts': profit_amounts
        }
    
    def _calculate_profit_targets(self, entry_price: float, direction: str, 
                                position_size_lots: float, pip_value: float,
                                signal_data: dict, is_news_trade: bool) -> Dict:
        """Calculate profit targets for any trade (news or regular)"""
        
        # Base profit distances in pips
        if is_news_trade and 'expected_move' in signal_data:
            # News trade - use expected move
            base_move = signal_data['expected_move'] / 0.0001  # Convert to pips
            event_type = signal_data.get('event_type')
            multiplier = 1.0
            if event_type:
                # Get news multiplier if it's a news event
                for news_event, mult in self.news_profit_multipliers.items():
                    if event_type in news_event.value:
                        multiplier = mult
                        break
        else:
            # Regular trade - conservative targets for 20% risk model
            base_move = 100  # 100 pips base move
            multiplier = 1.0  # No multiplier for regular trades
        
        # Calculate targets with your aggressive model
        target_distances = [
            base_move * 0.5 * multiplier,   # Quick target: 50% of expected
            base_move * 1.0 * multiplier,   # Base target: 100% of expected  
            base_move * 1.5 * multiplier,   # Extended: 150% of expected
            base_move * 2.5 * multiplier    # Aggressive: 250% of expected
        ]
        
        # Calculate target prices
        if direction == 'BUY':
            target_prices = [entry_price + (dist * 0.0001) for dist in target_distances]
        else:
            target_prices = [entry_price - (dist * 0.0001) for dist in target_distances]
        
        # Calculate profit amounts
        profit_amounts = []
        for i, distance in enumerate(target_distances):
            profit_amount = position_size_lots * distance * pip_value
            profit_amounts.append(profit_amount)
        
        return {
            'prices': target_prices,
            'amounts': profit_amounts
        }
    
    def _calculate_expected_daily_return_flexible(self, profit_targets: Dict, 
                                                leverage_used: float, risk_percentage: float) -> float:
        """Calculate expected daily return for any trade"""
        # Conservative approach: 70% chance of hitting first target
        hit_probability = 0.70
        
        # Expected profit from first target (most conservative)
        expected_profit = profit_targets['amounts'][0] * hit_probability
        
        # Calculate daily return percentage
        daily_return = expected_profit / self.account_balance
        
        return daily_return
    
    def _calculate_expected_daily_return(self, news_signal: NewsSignal, 
                                       profit_targets: Dict, 
                                       leverage_used: float) -> float:
        """Calculate expected daily return percentage"""
        # Use probability of hitting first target (most likely)
        # Conservative estimate: 70% chance of hitting first target
        hit_probability = 0.70
        
        # Expected profit from first target
        expected_profit = profit_targets['amounts'][0] * hit_probability
        
        # Calculate daily return percentage
        daily_return = expected_profit / self.account_balance
        
        return daily_return
    
    def get_position_management_rules(self, position: HighLeveragePosition) -> Dict:
        """Get position management rules for high leverage news trading"""
        return {
            'partial_exits': [
                {'target': 1, 'percent': 0.25, 'amount': position.target_profit_amounts[0]},  # Take 25% at first target
                {'target': 2, 'percent': 0.35, 'amount': position.target_profit_amounts[1]},  # Take 35% at second target
                {'target': 3, 'percent': 0.25, 'amount': position.target_profit_amounts[2]},  # Take 25% at third target
                {'target': 4, 'percent': 0.15, 'amount': position.target_profit_amounts[3]}   # Take 15% at fourth target
            ],
            'aggressive_management': {
                'quick_profit_lock': True,        # Lock in profits quickly
                'trailing_stop_aggressive': True, # Tight trailing stops
                'time_limit_strict': True,        # Strict time limits
                'breakeven_fast': True            # Move to breakeven fast
            },
            'risk_controls': {
                'max_leverage': self.max_leverage,
                'max_risk_per_trade': self.max_risk_percentage,
                'daily_loss_limit': 0.25,        # Stop trading after 25% daily loss
                'position_scaling': True,         # Scale into positions
                'news_only': True                 # Only trade during news
            },
            'profit_optimization': {
                'target_daily_return': self.target_daily_return,
                'compound_profits': True,         # Compound profitable trades
                'scale_on_success': True,        # Increase size after wins
                'reduce_on_failure': True        # Reduce size after losses
            }
        }
    
    def calculate_daily_profit_potential(self, positions: List[HighLeveragePosition]) -> Dict:
        """Calculate potential daily profit from multiple positions"""
        total_risk = sum(pos.risk_amount for pos in positions)
        total_potential_profit = sum(pos.target_profit_amounts[0] for pos in positions)  # First target
        
        # Conservative success rate for news trading
        success_rate = 0.75  # 75% hit rate on first targets
        
        expected_daily_profit = total_potential_profit * success_rate
        expected_daily_return = expected_daily_profit / self.account_balance
        
        return {
            'positions': len(positions),
            'total_risk_amount': total_risk,
            'total_risk_percentage': total_risk / self.account_balance,
            'potential_profit': total_potential_profit,
            'expected_profit': expected_daily_profit,
            'expected_daily_return': expected_daily_return,
            'target_achieved': expected_daily_return >= self.target_daily_return,
            'leverage_utilization': sum(pos.leverage_used for pos in positions) / len(positions) if positions else 0
        }
    
    def update_account_balance(self, new_balance: float):
        """Update account balance for dynamic position sizing"""
        self.account_balance = new_balance
        logger.info(f"Account balance updated to ${new_balance:,.2f}")


def demonstrate_aggressive_position_management():
    """Demonstrate aggressive position management for news trading"""
    from news_event_trading_suite import NewsEventTradingSuite, NewsEventType
    from test_signal_engine import generate_test_data
    
    print("="*80)
    print("AGGRESSIVE POSITION MANAGER - 100:1+ LEVERAGE NEWS TRADING")
    print("Target: 10%+ Daily Returns with 20% Risk Model")
    print("="*80)
    
    # Initialize systems
    news_trader = NewsEventTradingSuite()
    position_manager = AggressivePositionManager(account_balance=10000)
    
    print(f"\n💰 Account Setup:")
    print(f"Account Balance: ${position_manager.account_balance:,.2f}")
    print(f"Maximum Risk per Trade: {position_manager.max_risk_percentage:.0%}")
    print(f"Target Daily Return: {position_manager.target_daily_return:.0%}")
    print(f"Maximum Leverage: {position_manager.max_leverage}:1")
    
    # Generate test scenarios
    scenarios = [
        (NewsEventType.FOMC_RATE, "Maximum Risk - FOMC Rate Decision"),
        (NewsEventType.BOE_RATE, "High Risk - BOE Rate Decision"),
        (NewsEventType.NFP, "High Risk - Non-Farm Payrolls"),
        (NewsEventType.ECB_RATE, "Elevated Risk - ECB Rate Decision")
    ]
    
    positions = []
    
    for event_type, description in scenarios:
        print(f"\n📊 {description}")
        print("-" * 50)
        
        # Generate test data
        df = generate_test_data('GBPUSD', periods=200)
        
        # Create mock news signal
        current_price = 1.2700
        expected_move = {
            NewsEventType.FOMC_RATE: 0.0200,  # 200 pips
            NewsEventType.BOE_RATE: 0.0180,   # 180 pips
            NewsEventType.NFP: 0.0150,        # 150 pips
            NewsEventType.ECB_RATE: 0.0120    # 120 pips
        }[event_type]
        
        # Mock news signal (simplified)
        class MockNewsSignal:
            def __init__(self, event_type):
                from news_event_trading_suite import NewsEvent, NewsStrategy, NewsTradingPhase
                from indicators.base import SignalStrength
                
                self.event = type('obj', (object,), {
                    'event_type': event_type,
                    'symbol': 'GBPUSD'
                })()
                self.strategy = NewsStrategy.MOMENTUM_FOLLOW
                self.phase = NewsTradingPhase.INITIAL_MOVE
                self.direction = SignalStrength.BUY
                self.entry_price = current_price
                self.stop_loss = current_price - expected_move * 0.3
                self.take_profit_1 = current_price + expected_move * 0.5
                self.take_profit_2 = current_price + expected_move * 0.8
                self.take_profit_3 = current_price + expected_move * 1.2
                self.confidence = 0.85
        
        mock_signal = MockNewsSignal(event_type)
        
        # Calculate aggressive position
        position = position_manager.calculate_aggressive_position(mock_signal)
        positions.append(position)
        
        print(f"Event Type: {event_type.value}")
        print(f"Position Size: {position.position_size_lots:.2f} lots")
        print(f"Position Value: ${position.position_value_usd:,.0f}")
        print(f"Leverage Used: {position.leverage_used:.0f}:1")
        print(f"Risk Amount: ${position.risk_amount:,.0f} ({position.risk_percentage:.0%})")
        print(f"Profit Target 1: ${position.target_profit_amounts[0]:,.0f}")
        print(f"Expected Daily Return: {position.expected_daily_return:.1%}")
    
    # Calculate combined daily potential
    daily_potential = position_manager.calculate_daily_profit_potential(positions)
    
    print(f"\n" + "="*80)
    print("DAILY PROFIT POTENTIAL ANALYSIS")
    print("="*80)
    print(f"Total Positions: {daily_potential['positions']}")
    print(f"Total Risk: ${daily_potential['total_risk_amount']:,.0f} ({daily_potential['total_risk_percentage']:.0%})")
    print(f"Potential Profit: ${daily_potential['potential_profit']:,.0f}")
    print(f"Expected Profit: ${daily_potential['expected_profit']:,.0f}")
    print(f"Expected Daily Return: {daily_potential['expected_daily_return']:.1%}")
    print(f"Target Achievement: {'✅ YES' if daily_potential['target_achieved'] else '❌ NO'}")
    print(f"Average Leverage: {daily_potential['leverage_utilization']:.0f}:1")
    
    # Show position management rules
    if positions:
        rules = position_manager.get_position_management_rules(positions[0])
        print(f"\n📋 POSITION MANAGEMENT RULES:")
        print("Partial Exits:")
        for exit_rule in rules['partial_exits']:
            print(f"  Target {exit_rule['target']}: {exit_rule['percent']:.0%} (${exit_rule['amount']:,.0f})")
        
        print(f"\nRisk Controls:")
        print(f"  Max Leverage: {rules['risk_controls']['max_leverage']}:1")
        print(f"  Max Risk/Trade: {rules['risk_controls']['max_risk_per_trade']:.0%}")
        print(f"  Daily Loss Limit: {rules['risk_controls']['daily_loss_limit']:.0%}")
    
    print(f"\n" + "="*80)
    print("KEY BENEFITS:")
    print("• 100:1+ leverage utilization for maximum capital efficiency")
    print("• 20% risk per trade on major news events")
    print("• 10%+ daily return targeting through aggressive profit taking")
    print("• Event-specific risk allocation and profit scaling")
    print("• Multiple profit targets with quick exit strategies")
    print("• Strict risk controls with daily loss limits")
    print("="*80)
    
    return positions, daily_potential


if __name__ == "__main__":
    demonstrate_aggressive_position_management()