import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'pages/discover_page.dart';
import 'pages/explore_page.dart';
import 'pages/inbox_page.dart';
import 'pages/post_page.dart';
import 'pages/profile_page.dart';
import 'pages/notifications_page.dart';
import 'widgets/nav_items.dart';

// ─────────────────────────────────────────────
// HomeScope
// Passes unread count + callbacks down the tree
// so DiscoverPage bell and ProfilePage logout work
// ─────────────────────────────────────────────

class HomeScope extends InheritedWidget {
  final int unreadCount;
  final VoidCallback? onBellTap;
  final VoidCallback? onLogout;

  const HomeScope({
    super.key,
    required super.child,
    required this.unreadCount,
    this.onBellTap,
    this.onLogout,
  });

  static HomeScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeScope>();

  @override
  bool updateShouldNotify(HomeScope old) =>
      unreadCount != old.unreadCount;
}

// ─────────────────────────────────────────────
// HomePage
// ─────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Pages: 0=Discover  1=Explore  2=Inbox  3=Profile
  int _currentIndex = 0;
  int _unreadCount  = 0;
  int _unreadMsgs   = 0;

  RealtimeChannel? _notifChannel;
  RealtimeChannel? _msgChannel;

  static const _pages = [
    DiscoverPage(),
    ExplorePage(),
    InboxPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _loadUnreadMessages();
    _subscribeToNotifications();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _notifChannel?.unsubscribe();
    _msgChannel?.unsubscribe();
    super.dispose();
  }

  // ── Unread counts ──────────────────────────────────────────────────────────

  Future<void> _loadUnreadCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final data = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      if (mounted) setState(() => _unreadCount = (data as List).length);
    } catch (_) {}
  }

  Future<void> _loadUnreadMessages() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final convs = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .or('participant_1.eq.${user.id},participant_2.eq.${user.id}');
      if ((convs as List).isEmpty) {
        if (mounted) setState(() => _unreadMsgs = 0);
        return;
      }
      int total = 0;
      for (final c in convs) {
        final unread = await Supabase.instance.client
            .from('messages')
            .select('id')
            .eq('conversation_id', c['id'])
            .eq('is_read', false)
            .neq('sender_id', user.id);
        total += (unread as List).length;
      }
      if (mounted) setState(() => _unreadMsgs = total);
    } catch (_) {}
  }

  void _subscribeToNotifications() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _notifChannel = Supabase.instance.client
        .channel('notifs:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
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

  void _subscribeToMessages() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _msgChannel = Supabase.instance.client
        .channel('msgs:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) => _loadUnreadMessages(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (_) => _loadUnreadMessages(),
        )
        .subscribe();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  // Bottom nav:  0=Home  1=Explore  2=Inbox  3=Post(+)  4=Profile
  // Page index:   0       1          2                    3

  void _onNavTap(int navIndex) {
    if (navIndex == 3) {
      // Post (+) button — show bottom sheet, don't change page
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const PostPage(),
      );
      return;
    }
    final pageIndex = navIndex < 3 ? navIndex : navIndex - 1;
    setState(() => _currentIndex = pageIndex);
  }

  // Convert page index → nav highlight index
  int get _navIndex => _currentIndex < 3 ? _currentIndex : _currentIndex + 1;

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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
      _msgChannel?.unsubscribe();
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        onPopInvokedWithResult: (didPop, _) {
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
          // AppBar only on Explore tab
          appBar: _currentIndex == 1
              ? AppBar(
                  backgroundColor: AppColors.surface,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  title: const Text('Explore',
                      style: AppTextStyles.titleLarge),
                  actions: [
                    _NotifBell(
                      unreadCount: _unreadCount,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsPage()),
                        );
                        _loadUnreadCount();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              : null,
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              MessageNavItem(
                unreadCount: _unreadMsgs,
                isSelected: _navIndex == 2,
                onTap: () => _onNavTap(2),
              ),
              PostNavItem(onTap: () => _onNavTap(3)),
              NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isSelected: _navIndex == 4,
                onTap: () => _onNavTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Notification Bell (AppBar action)
// ─────────────────────────────────────────────

class _NotifBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotifBell({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
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
          if (unreadCount > 0)
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
                    unreadCount > 9 ? '9+' : '$unreadCount',
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
    );
  }
}