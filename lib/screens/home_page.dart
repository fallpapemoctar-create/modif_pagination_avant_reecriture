import 'package:flutter/material.dart';
import '../core/auth_manager.dart';
import '../core/user_rights.dart';
import '../core/responsive_helper.dart';
import '../pages/interpreters_page.dart';
import '../pages/missions_page.dart';
import '../screens/admin_page.dart';

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
      tabs.add(const Tab(icon: Icon(Icons.work), text: "Missions"));
      views.add( MissionsPage(userRights: rights));
    }
    if (rights.isAdmin()) {
      tabs.add(const Tab(icon: Icon(Icons.admin_panel_settings), text: "Admin"));
      views.add(AdminPage(userRights: rights));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.transparent,
                    child: const Icon(Icons.public, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gesplanet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Bienvenue ${AuthManager.userFullName}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          bottom: TabBar(
            tabs: tabs,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                AuthManager.logout();
                Navigator.pushReplacementNamed(context, "/login");
              },
            )
          ],
        ),
        body: TabBarView(children: views),
      ),
    );
  }

  // ------------------------------------------------------------
  // 📱 LAYOUT MOBILE : DASHBOARD EN CARTES
  // ------------------------------------------------------------
  Widget _buildMobileLayout(UserRights rights, BuildContext context) {
    final logoSize = ResponsiveHelper.isMobile(context) ? 36.0 : 40.0;
    
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ResponsiveHelper.isMobile(context) ? 60 : 68,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/logo.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: logoSize,
                  height: logoSize,
                  color: Colors.transparent,
                  child: Icon(Icons.public, size: logoSize * 0.6),
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
                    'Gesplanet',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context, base: 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Bienvenue ${AuthManager.userFullName}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context, base: 11),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthManager.logout();
              Navigator.pushReplacementNamed(context, "/login");
            },
            tooltip: 'Déconnexion',
          )
        ],
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
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, "/interpreters"),
              ),
            if (rights.canManageMissions() || rights.isAdmin())
              _dashboardCard(
                context: context,
                icon: Icons.work,
                label: "Missions",
                color: Colors.green,
                onTap: () => Navigator.pushNamed(context, "/missions"),
              ),
            if (rights.isAdmin())
              _dashboardCard(
                context: context,
                icon: Icons.admin_panel_settings,
                label: "Admin",
                color: Colors.purple,
                onTap: () => Navigator.pushNamed(context, "/admin"),
              ),
          ],
        ),
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
      elevation: ResponsiveHelper.getCardElevation(context),
      shape: RoundedRectangleBorder(
        borderRadius: ResponsiveHelper.getBorderRadius(context),
      ),
      child: InkWell(
        borderRadius: ResponsiveHelper.getBorderRadius(context),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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