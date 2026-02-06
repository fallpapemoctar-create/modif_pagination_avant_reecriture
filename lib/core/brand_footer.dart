import 'package:flutter/material.dart';

class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    // Render nothing to remove footer text globally while keeping layout intact
    return const SizedBox.shrink();
  }
}
