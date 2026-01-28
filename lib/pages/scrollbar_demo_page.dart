import 'package:flutter/material.dart';
import '../core/custom_scrollbar.dart';
import '../core/responsive_helper.dart';

/// Page de démonstration des différentes variantes de scrollbars DSFR
/// 
/// Cette page peut être utilisée pour :
/// - Visualiser les différents styles de scrollbar
/// - Tester le comportement responsive
/// - Comparer les couleurs
class ScrollbarDemoPage extends StatefulWidget {
  const ScrollbarDemoPage({super.key});

  @override
  State<ScrollbarDemoPage> createState() => _ScrollbarDemoPageState();
}

class _ScrollbarDemoPageState extends State<ScrollbarDemoPage> {
  final ScrollController _blueController = ScrollController();
  final ScrollController _redController = ScrollController();
  final ScrollController _grayController = ScrollController();
  final ScrollController _customController = ScrollController();

  @override
  void dispose() {
    _blueController.dispose();
    _redController.dispose();
    _grayController.dispose();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF000091),
        foregroundColor: Colors.white,
        title: const Text(
          'Démonstration Scrollbars DSFR',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context)),
        child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return ListView(
      children: [
        _buildScrollbarDemo(
          'DsfrScrollbar (Blue France)',
          _blueController,
          const Color(0xFF000091),
          DsfrScrollbar(
            controller: _blueController,
            child: _buildDemoList(_blueController),
          ),
        ),
        const SizedBox(height: 24),
        _buildScrollbarDemo(
          'DsfrScrollbarRed (Red Marianne)',
          _redController,
          const Color(0xFFE1000F),
          DsfrScrollbarRed(
            controller: _redController,
            child: _buildDemoList(_redController),
          ),
        ),
        const SizedBox(height: 24),
        _buildScrollbarDemo(
          'DsfrScrollbarGray (Subtile)',
          _grayController,
          const Color(0xFF666666),
          DsfrScrollbarGray(
            controller: _grayController,
            child: _buildDemoList(_grayController),
          ),
        ),
        const SizedBox(height: 24),
        _buildScrollbarDemo(
          'CustomScrollbar (Vert personnalisé)',
          _customController,
          const Color(0xFF18753C),
          CustomScrollbar(
            controller: _customController,
            thumbColor: const Color(0xFF18753C),
            trackColor: const Color(0xFFB8FEC9),
            child: _buildDemoList(_customController),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 0.8,
      children: [
        _buildScrollbarDemo(
          'DsfrScrollbar (Blue France)',
          _blueController,
          const Color(0xFF000091),
          DsfrScrollbar(
            controller: _blueController,
            child: _buildDemoList(_blueController),
          ),
        ),
        _buildScrollbarDemo(
          'DsfrScrollbarRed (Red Marianne)',
          _redController,
          const Color(0xFFE1000F),
          DsfrScrollbarRed(
            controller: _redController,
            child: _buildDemoList(_redController),
          ),
        ),
        _buildScrollbarDemo(
          'DsfrScrollbarGray (Subtile)',
          _grayController,
          const Color(0xFF666666),
          DsfrScrollbarGray(
            controller: _grayController,
            child: _buildDemoList(_grayController),
          ),
        ),
        _buildScrollbarDemo(
          'CustomScrollbar (Vert personnalisé)',
          _customController,
          const Color(0xFF18753C),
          CustomScrollbar(
            controller: _customController,
            thumbColor: const Color(0xFF18753C),
            trackColor: const Color(0xFFB8FEC9),
            child: _buildDemoList(_customController),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollbarDemo(String title, ScrollController controller, Color color, Widget scrollbarWidget) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF161616),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: scrollbarWidget,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoList(ScrollController controller) {
    return ListView.builder(
      controller: controller,
      itemCount: 50,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: index % 2 == 0 ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF000091),
                radius: 16,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Élément ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF161616),
                      ),
                    ),
                    Text(
                      'Description de l\'élément numéro ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
