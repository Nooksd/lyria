import 'package:flutter/material.dart';

class CustomNavigationDestination extends StatelessWidget {
  final Icon icon;
  final String label;
  final bool isSelected;

  const CustomNavigationDestination({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationDestination(
      icon: Container(
        child: icon,
      ),
      label: label,
    );
  }
}
