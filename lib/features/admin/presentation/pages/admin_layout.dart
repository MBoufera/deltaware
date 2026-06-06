import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  
  const AdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Check if the screen is large enough for a persistent sidebar
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      drawer: isDesktop ? null : _AdminSidebar(isDrawer: true),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1A2A32),
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Deltaware Admin', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: Row(
        children: [
          if (isDesktop) const _AdminSidebar(isDrawer: false),
          Expanded(
            child: ClipRRect(
              // Give the content area rounded corners on desktop for a premium feel
              borderRadius: isDesktop ? const BorderRadius.only(topLeft: Radius.circular(30), bottomLeft: Radius.circular(30)) : BorderRadius.zero,
              child: Container(
                color: const Color(0xFFF4F7F6),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  final bool isDrawer;
  
  const _AdminSidebar({required this.isDrawer});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    final sidebarContent = Container(
      width: 260,
      color: const Color(0xFF1A2A32),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Icon(Icons.dashboard_customize, color: Colors.blue.shade300, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Deltaware',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          
          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _SidebarItem(
                  icon: Icons.pie_chart_outline,
                  label: 'Overview',
                  isActive: location == '/admin-dashboard',
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin-dashboard');
                  },
                ),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Icons.document_scanner_outlined,
                  label: 'Smart Invoice',
                  isActive: location.startsWith('/admin-dashboard/smart-batch'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin-dashboard/smart-batch');
                  },
                ),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Inventory',
                  isActive: location.startsWith('/admin-dashboard/products'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin-dashboard/products');
                  },
                ),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Icons.people_outline,
                  label: 'Users',
                  isActive: location.startsWith('/admin-dashboard/users'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin-dashboard/users');
                  },
                ),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Icons.security_outlined,
                  label: 'Roles',
                  isActive: location.startsWith('/admin-dashboard/roles'),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    context.go('/admin-dashboard/roles');
                  },
                ),
              ],
            ),
          ),
          
          // Bottom User Profile
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.shade900,
                  child: const Text('AD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'admin@deltaware',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                  onPressed: () {
                    context.go('/');
                  },
                  tooltip: 'Log Out',
                )
              ],
            ),
          )
        ],
      ),
    );

    return isDrawer ? Drawer(child: sidebarContent) : sidebarContent;
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? Colors.white : (_isHovered ? Colors.white : Colors.white60);
    final bgColor = widget.isActive 
        ? Colors.blue.withValues(alpha: 0.15) 
        : (_isHovered ? Colors.white.withValues(alpha: 0.05) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: widget.isActive 
                ? Border.all(color: Colors.blue.withValues(alpha: 0.3)) 
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 22),
              const SizedBox(width: 16),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
