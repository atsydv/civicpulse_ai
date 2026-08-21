import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class DemoCredentialsWidget extends StatelessWidget {
  final void Function(String email, String password) onAutofill;

  const DemoCredentialsWidget({super.key, required this.onAutofill});

  static const List<Map<String, String>> _credentials = [
    {
      'role': 'Citizen',
      'email': 'citizen@civic.local',
      'password': 'demo123',
      'icon': 'person_outline',
      'color': '0xFF10B981',
    },
    {
      'role': 'Admin',
      'email': 'admin@civic.local',
      'password': 'demo123',
      'icon': 'admin_panel_settings',
      'color': '0xFF3B82F6',
    },
    {
      'role': 'Worker',
      'email': 'worker@civic.local',
      'password': 'demo123',
      'icon': 'engineering',
      'color': '0xFFF97316',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(20), width: 1),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomIconWidget(
                    iconName: 'key',
                    color: const Color(0xFF94A3B8),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Demo Accounts — tap to autofill',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ..._credentials.map((cred) {
                final color = Color(int.parse(cred['color']!));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => onAutofill(cred['email']!, cred['password']!),
                    borderRadius: BorderRadius.circular(12),
                    splashColor: color.withAlpha(26),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withAlpha(51),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withAlpha(38),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: CustomIconWidget(
                                iconName: cred['icon']!,
                                color: color,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cred['role']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cred['email']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha(38),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Use',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
