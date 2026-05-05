import 'package:flutter/material.dart';
import '../../main.dart';
import '../../utils/responsive.dart';

// ─────────────────────────────────────────────
// Payment Methods Page
// ─────────────────────────────────────────────

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  int _defaultIndex = 0;

  final List<_CardItem> _cards = [
    _CardItem(
      type: CardType.visa,
      lastFour: '4821',
      holder: 'Vicky Prince',
      expiry: '08 / 26',
      gradientColors: [Color(0xFF1A56DB), Color(0xFF06B6D4)],
    ),
    _CardItem(
      type: CardType.mastercard,
      lastFour: '7734',
      holder: 'Vicky Prince',
      expiry: '03 / 28',
      gradientColors: [Color(0xFF1F2937), Color(0xFF374151)],
    ),
  ];

  void _removeCard(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Card',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to remove this card?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cards.removeAt(index);
                if (_defaultIndex >= _cards.length) _defaultIndex = 0;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddCard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCardSheet(
        onAdd: (card) => setState(() => _cards.add(card)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = R.pad(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Payment Methods', style: AppTextStyles.titleLarge),
      ),
      body: R.constrain(
        context,
        ListView(
          padding: EdgeInsets.symmetric(horizontal: p, vertical: 20),
          children: [
            // ── Wallet Balance ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                        '₦ 47,500.00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Top Up'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Cards', style: AppTextStyles.titleLarge),
                TextButton.icon(
                  onPressed: _showAddCard,
                  icon: const Icon(Icons.add_rounded,
                      size: 16, color: AppColors.primary),
                  label: const Text(
                    'Add New',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_cards.isEmpty)
              _EmptyCards(onAdd: _showAddCard)
            else
              ...List.generate(_cards.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CardTile(
                    card: _cards[index],
                    isDefault: _defaultIndex == index,
                    onSetDefault: () => setState(() => _defaultIndex = index),
                    onRemove: () => _removeCard(index),
                  ),
                );
              }),

            const SizedBox(height: 28),

            // ── Payment Options ──
            const Text('Other Payment Options', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            _PaymentOptionTile(
              icon: Icons.phone_android_rounded,
              color: const Color(0xFF10B981),
              title: 'USSD / Bank Transfer',
              subtitle: 'Pay directly from your bank account',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _PaymentOptionTile(
              icon: Icons.savings_rounded,
              color: const Color(0xFF6366F1),
              title: 'Opay / Palmpay',
              subtitle: 'Link your mobile money account',
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _PaymentOptionTile(
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Pay on Delivery',
              subtitle: 'Cash payment when service is done',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Models & Enums
// ─────────────────────────────────────────────

enum CardType { visa, mastercard }

class _CardItem {
  final CardType type;
  final String lastFour;
  final String holder;
  final String expiry;
  final List<Color> gradientColors;

  _CardItem({
    required this.type,
    required this.lastFour,
    required this.holder,
    required this.expiry,
    required this.gradientColors,
  });
}

// ─────────────────────────────────────────────
// Card Tile Widget
// ─────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final _CardItem card;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  const _CardTile({
    required this.card,
    required this.isDefault,
    required this.onSetDefault,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: card.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: card.gradientColors.first.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card.type == CardType.visa ? 'VISA' : 'MASTERCARD',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Row(
                children: [
                  if (isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: Colors.white70, size: 20),
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onSelected: (val) {
                      if (val == 'default') onSetDefault();
                      if (val == 'remove') onRemove();
                    },
                    itemBuilder: (_) => [
                      if (!isDefault)
                        const PopupMenuItem(
                          value: 'default',
                          child: Text('Set as Default'),
                        ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove Card',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '•••• •••• •••• ${card.lastFour}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Card Holder',
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(card.holder,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expires',
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(card.expiry,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Payment Option Tile
// ─────────────────────────────────────────────

class _PaymentOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────

class _EmptyCards extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCards({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.credit_card_rounded,
                size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text('No cards added yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Add a debit or credit card to pay easily',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Card'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Add Card Bottom Sheet
// ─────────────────────────────────────────────

class _AddCardSheet extends StatefulWidget {
  final void Function(_CardItem) onAdd;
  const _AddCardSheet({required this.onAdd});

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _numberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final number = _numberCtrl.text.trim();
    if (number.length < 4) return;
    final lastFour = number.substring(number.length - 4);
    widget.onAdd(_CardItem(
      type: CardType.visa,
      lastFour: lastFour,
      holder: _nameCtrl.text.trim().isEmpty ? 'Card Holder' : _nameCtrl.text.trim(),
      expiry: _expiryCtrl.text.trim().isEmpty ? '-- / --' : _expiryCtrl.text.trim(),
      gradientColors: const [Color(0xFF1A56DB), Color(0xFF06B6D4)],
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Add New Card', style: AppTextStyles.titleLarge),
          const SizedBox(height: 20),
          AppTextField(
            controller: _numberCtrl,
            label: 'Card Number',
            hint: '0000 0000 0000 0000',
            prefixIcon: Icons.credit_card_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _nameCtrl,
            label: 'Card Holder Name',
            hint: 'As shown on card',
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _expiryCtrl,
                  label: 'Expiry',
                  hint: 'MM / YY',
                  prefixIcon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _cvvCtrl,
                  label: 'CVV',
                  hint: '•••',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GradientButton(label: 'Save Card', onPressed: _submit),
        ],
      ),
    );
  }
}