import 'package:flutter/material.dart';

class DepositRequiredModal extends StatelessWidget {
  final double totalBalance;
  final String currency;
  final VoidCallback? onDepositTap;

  const DepositRequiredModal({
    super.key,
    required this.totalBalance,
    required this.currency,
    this.onDepositTap,
  });

  String _formatAmount(double v) {
    // simple format: 2 decimals
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A1F35).withOpacity(0.98),
                const Color(0xFF0F1419).withOpacity(0.98),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: 5,
              ),
              BoxShadow(
                color: const Color(0xFF637BFF).withOpacity(0.15),
                blurRadius: 60,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon bubble with animated gradient
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF21C8F6).withOpacity(0.3),
                          const Color(0xFF637BFF).withOpacity(0.3),
                          const Color(0xFF8B5CF6).withOpacity(0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Main icon circle
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF21C8F6),
                          const Color(0xFF637BFF),
                          const Color(0xFF8B5CF6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF637BFF).withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Title with gradient text effect
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFE0E7FF),
                  ],
                ).createShader(bounds),
                child: const Text(
                  'Ready to Play?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Let\'s add some funds to get started!\nUnlock endless gaming excitement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 24),

              // Balance pill with enhanced styling
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    // Icon with background
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF637BFF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: const Color(0xFF637BFF).withOpacity(0.9),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Balance',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.60),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                currency,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatAmount(totalBalance),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.20),
                          width: 1.5,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.03),
                      ),
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF21C8F6),
                            Color(0xFF637BFF),
                            Color(0xFF8B5CF6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF637BFF).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDepositTap?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Add Funds',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Subtle helper text
              Text(
                '✨ Quick & secure deposits',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show it easily
Future<void> showDepositRequiredModal(
  BuildContext context, {
  required double totalBalance,
  required String currency,
  VoidCallback? onDepositTap,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (_) => DepositRequiredModal(
      totalBalance: totalBalance,
      currency: currency,
      onDepositTap: onDepositTap,
    ),
  );
}