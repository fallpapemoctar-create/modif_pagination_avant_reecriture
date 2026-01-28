import 'package:flutter/material.dart';
import 'responsive_helper.dart';

class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: ResponsiveHelper.getSpacing(context)),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'AMI — Assistance Missions Interprètes · by Smart Technologie',
          style: TextStyle(
            fontSize: ResponsiveHelper.getFontSize(context, base: 11),
            color: const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}
