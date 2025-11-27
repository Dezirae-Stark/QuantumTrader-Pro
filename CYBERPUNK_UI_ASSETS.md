# Cyberpunk UI Assets

## App Icons (To be generated)

### Android Icons (android/app/src/main/res/)
- mipmap-mdpi/ic_launcher.png (48x48)
- mipmap-hdpi/ic_launcher.png (72x72)
- mipmap-xhdpi/ic_launcher.png (96x96)
- mipmap-xxhdpi/ic_launcher.png (144x144)
- mipmap-xxxhdpi/ic_launcher.png (192x192)

### Icon Design Specifications
- Background: Deep black (#050509) with quantum wave pattern
- Foreground: Neon cyan "Q" with beveled 3D effect
- Glow: Cyan outer glow with magenta accent
- Style: Professional, minimalist, cyberpunk aesthetic

### Menu Icons Used (Material Icons)
- Dashboard: Icons.dashboard
- Portfolio: Icons.account_balance_wallet
- Quantum/Analysis: Icons.psychology
- Settings: Icons.settings

## Color Palette
- Background Primary: #050509
- Background Secondary: #0A0A0F
- Surface: #1A1A23
- Neon Cyan: #00E5FF
- Neon Magenta: #D500F9
- Neon Green: #76FF03
- Warning: #FFB300
- Error: #FF3D3D
- Bullish: #00E676
- Bearish: #FF5252

## Typography
- Headlines: Orbitron (Google Fonts)
- Body: Rajdhani (Google Fonts)
- Mono: JetBrains Mono

## UI Components Created
1. QuantumCard - Beveled card with optional glow
2. QuantumButton - Multiple variants with press animations
3. QuantumToggle - Custom cyberpunk toggle switch
4. QuantumSlider - Gradient slider with dynamic colors
5. QuantumSegmentedControl - Tab selector with neon highlights
6. QuantumWallpaper - Animated quantum wave background

## Screen Implementations
1. CyberpunkDashboardScreen - Complete dashboard with connection pills and market overview
2. CyberpunkPortfolioScreen - Portfolio with dynamic P&L glow and trade cards
3. CyberpunkQuantumScreen - Quantum system controls with module status
4. CyberpunkSettingsScreen - Settings with collapsible sections and theme controls

## Animation Specifications
- Page transitions: 800ms ease-out fade
- Button press: 100ms scale to 0.95
- Toggle animation: 200ms cubic-bezier
- Glow pulse: 2-3s ease-in-out loop
- Card hover: 200ms elevation change

## Testing Checklist
- [ ] Test on Android emulator (API 30+)
- [ ] Test on physical Android device
- [ ] Verify dark mode only behavior
- [ ] Check text readability on all screens
- [ ] Validate touch targets (min 48dp)
- [ ] Test landscape orientation
- [ ] Verify performance with animations
- [ ] Check accessibility with TalkBack