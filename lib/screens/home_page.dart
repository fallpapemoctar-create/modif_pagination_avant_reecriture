import 'package:flutter/material.dart';
import '../core/auth_manager.dart';
import '../core/user_rights.dart';
import '../core/responsive_helper.dart';
import '../pages/interpreters_page.dart';
import '../pages/missions_table_page.dart';
import '../pages/billing_page.dart';
import '../screens/admin_page.dart';
import '../screens/export_page.dart';
import '../core/brand_footer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final rights = AuthManager.userRights;

    // Use responsive helper instead of LayoutBuilder
    if (ResponsiveHelper.isDesktop(context)) {
      return _buildDesktopLayout(rights, context);
    }

    return _buildMobileLayout(rights, context);
  }

  // ------------------------------------------------------------
  // 🖥️ LAYOUT DESKTOP / WEB : TABBAR MODERNE
  // ------------------------------------------------------------
  Widget _buildDesktopLayout(UserRights rights, BuildContext context) {
    final tabs = <Tab>[];
    final views = <Widget>[];

    if (rights.canManageInterpreters() || rights.isAdmin()) {
      tabs.add(const Tab(icon: Icon(Icons.people), text: "Interprètes"));
      views.add(InterpretersPage(userRights: rights));
    }
    if (rights.canManageMissions() || rights.isAdmin()) {
      tabs.add(const Tab(icon: Icon(Icons.table_rows), text: "Missions (Tableau)"));
      views.add(MissionsTablePage(userRights: rights));
      tabs.add(const Tab(icon: Icon(Icons.receipt_long), text: "Facturation"));
      views.add(BillingPage(userRights: rights));
    }
    if (rights.isAdmin()) {
      tabs.add(const Tab(icon: Icon(Icons.admin_panel_settings), text: "Admin"));
      views.add(AdminPage(userRights: rights));
      tabs.add(const Tab(icon: Icon(Icons.download), text: "Export"));
      views.add(const ExportPage());
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF161616),
          elevation: 0,
          toolbarHeight: 72,
          title: Row(
            children: [
              // Logo Planet Traduction
              Image.asset(
                'assets/logo.png',
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF000091), width: 2),
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: const Text(
                    'RF',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF000091),
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Nom de l'application
              const Text(
                'AMI - Assistance missions interprètes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF161616),
                ),
              ),
              const Spacer(),
              // Utilisateur
              Text(
                'Bienvenue ${AuthManager.userFullName}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF3A3A3A),
                ),
              ),
              const SizedBox(width: 24),
              // Bouton déconnexion DSFR
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  color: const Color(0xFF000091),
                  iconSize: 20,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: 'Déconnexion',
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await AuthManager.logout();
                    if (!navigator.mounted) return;
                    navigator.pushReplacementNamed("/login");
                  },
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49.0),
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    tabs: tabs,
                    labelColor: const Color(0xFF000091),
                    unselectedLabelColor: const Color(0xFF666666),
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    indicator: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF000091),
                          width: 4,
                        ),
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                ),
                Container(
                  height: 1,
                  color: const Color(0xFFDDDDDD),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(children: views),
        bottomNavigationBar: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BrandFooter(),
          ),
      ),
    );
  }

  // ------------------------------------------------------------
  // 📱 LAYOUT MOBILE : DASHBOARD EN CARTES
  // ------------------------------------------------------------
  Widget _buildMobileLayout(UserRights rights, BuildContext context) {
      return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF161616),
        elevation: 0,
        toolbarHeight: ResponsiveHelper.isMobile(context) ? 64 : 72,
        title: Row(
          children: [
            // Logo Planet Traduction
            Image.asset(
              'assets/logo.png',
              height: ResponsiveHelper.isMobile(context) ? 40 : 48,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.isMobile(context) ? 8 : 12,
                  vertical: ResponsiveHelper.isMobile(context) ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF000091),
                    width: ResponsiveHelper.isMobile(context) ? 1.5 : 2,
                  ),
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Text(
                  'RF',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isMobile(context) ? 12 : 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF000091),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SizedBox(width: ResponsiveHelper.getSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AMI - Assistance missions interprètes',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context, base: 14),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF161616),
                    ),
                  ),
                  Text(
                    'Bienvenue ${AuthManager.userFullName}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context, base: 11),
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF666666),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(4),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, size: 20),
              color: const Color(0xFF000091),
              iconSize: 20,
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await AuthManager.logout();
                  if (!navigator.mounted) return;
                  navigator.pushReplacementNamed("/login");
              },
              tooltip: 'Déconnexion',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFDDDDDD),
            height: 1.0,
          ),
        ),
      ),
      body: ResponsiveContainer(
        child: GridView.count(
          crossAxisCount: ResponsiveHelper.isMobile(context) ? 1 : 3,
          padding: ResponsiveHelper.getPagePadding(context),
          mainAxisSpacing: ResponsiveHelper.getSpacing(context),
          crossAxisSpacing: ResponsiveHelper.getSpacing(context),
          childAspectRatio: ResponsiveHelper.isMobile(context) ? 1.2 : 1.4,
          children: [
            if (rights.canManageInterpreters() || rights.isAdmin())
              _dashboardCard(
                context: context,
                icon: Icons.people,
                label: "Interprètes",
                color: const Color(0xFF000091),
                onTap: () => Navigator.pushNamed(context, "/interpreters"),
              ),
            if (rights.canManageMissions() || rights.isAdmin())
              _dashboardCard(
                context: context,
                icon: Icons.table_view,
                label: "Missions (Tableau)",
                color: const Color(0xFF000091),
                onTap: () => Navigator.pushNamed(context, "/missions-table"),
              ),
            if (rights.canManageMissions() || rights.isAdmin())
              _dashboardCard(
                context: context,
                icon: Icons.receipt_long,
                label: "Facturation",
                color: const Color(0xFF000091),
                onTap: () => Navigator.pushNamed(context, "/billing"),
              ),
            if (rights.isAdmin())
              _dashboardCard(
                context: context,
                icon: Icons.admin_panel_settings,
                label: "Admin",
                color: const Color(0xFF000091),
                onTap: () => Navigator.pushNamed(context, "/admin"),
              ),
            if (rights.isAdmin())
              _dashboardCard(
                context: context,
                icon: Icons.download,
                label: "Export",
                color: const Color(0xFF000091),
                onTap: () => Navigator.pushNamed(context, "/export"),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: BrandFooter(),
      ),
    );
  }

  // ------------------------------------------------------------
  // 🧱 Widget Carte Dashboard
  // ------------------------------------------------------------
  Widget _dashboardCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final iconSize = ResponsiveHelper.isMobile(context) ? 36.0 : 44.0;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(
          color: Color(0xFFDDDDDD),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: iconSize, color: color),
              ),
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              Text(
                label,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context, base: 14),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}