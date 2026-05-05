import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'pages/discover_page.dart';
import 'pages/explore_page.dart';
import 'pages/post_page.dart';
import 'pages/profile_page.dart';
import 'pages/notifications_page.dart';
import 'widgets/nav_items.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  int _unreadCount = 0;

  RealtimeChannel? _notifChannel;

  static const _pages = [
    DiscoverPage(),
    ExplorePage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final data = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      if (mounted) {
        setState(() => _unreadCount = (data as List).length);
      }
    } catch (_) {}
  }

  void _subscribeToNotifications() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _notifChannel = Supabase.instance.client
        .channel('notifications:${user.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (_) => _loadUnreadCount(),
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (_) => _loadUnreadCount(),
    )
        .subscribe();
  }

  void _onNavTap(int navIndex) {
    if (navIndex == 2) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const PostPage(),
      );
      return;
    }
    final pageIndex = navIndex < 2 ? navIndex : navIndex - 1;
    setState(() => _currentIndex = pageIndex);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _notifChannel?.unsubscribe();
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  int get _navIndex => _currentIndex < 2 ? _currentIndex : _currentIndex + 1;

  // Expose logout and unread count so DiscoverPage and ProfilePage can use them
  // via the InheritedWidget below.

  @override
  Widget build(BuildContext context) {
    return HomeScope(
      unreadCount: _unreadCount,
      onBellTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
        _loadUnreadCount();
      },
      onLogout: _logout,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            if (_currentIndex != 0) {
              setState(() => _currentIndex = 0);
            } else {
              _logout();
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          // Discover has its own header with the bell built in.
          // Explore gets a clean app bar with the bell.
          // Profile has no app bar (full custom header).
          appBar: _currentIndex == 1 ? _buildExploreBar() : null,
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  // Explore tab app bar — bell on the right
  PreferredSizeWidget _buildExploreBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text('Explore', style: AppTextStyles.titleLarge),
      actions: [_notifBell(), const SizedBox(width: 8)],
    );
  }

  Widget _notifBell() {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_outlined,
                size: 18, color: AppColors.textSecondary),
          ),
          if (_unreadCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
        _loadUnreadCount();
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: _navIndex == 0,
                onTap: () => _onNavTap(0),
              ),
              NavItem(
                icon: Icons.search_rounded,
                label: 'Explore',
                isSelected: _navIndex == 1,
                onTap: () => _onNavTap(1),
              ),
              PostNavItem(onTap: () => _onNavTap(2)),
              NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isSelected: _navIndex == 3,
                onTap: () => _onNavTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// InheritedWidget — lets DiscoverPage reach the
// bell count + tap handler without prop drilling.
// ─────────────────────────────────────────────

class HomeScope extends InheritedWidget {
  final int unreadCount;
  final VoidCallback onBellTap;
  final VoidCallback onLogout;

  const HomeScope({
    required this.unreadCount,
    required this.onBellTap,
    required this.onLogout,
    required super.child,
  });

  static HomeScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeScope>();

  @override
  bool updateShouldNotify(HomeScope old) =>
      unreadCount != old.unreadCount;
}