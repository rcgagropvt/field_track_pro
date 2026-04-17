import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/offline_queue_service.dart';
import '../constants/app_colors.dart';

/// Drop this widget at the top of any Scaffold body to show
/// offline/pending sync state. It hides itself when online + no pending items.
class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner>
    with SingleTickerProviderStateMixin {
  bool _isOffline = false;
  int _pendingCount = 0;
  bool _isSyncing = false;
  StreamSubscription? _connectivitySub;
  Timer? _pollTimer;
  late AnimationController _animCtrl;
  late Animation<double> _heightAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _heightAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);

    _checkState();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((result) async {
      final offline = result == ConnectivityResult.none;
      if (mounted) setState(() => _isOffline = offline);
      await _refreshPending();
    });

    // Poll pending count every 5s so banner updates after background syncs
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _refreshPending());
  }

  Future<void> _checkState() async {
    final result = await Connectivity().checkConnectivity();
    final offline = result == ConnectivityResult.none;
    final pending = await OfflineQueueService.pendingCount();
    if (mounted) {
      setState(() {
        _isOffline = offline;
        _pendingCount = pending;
      });
      _updateAnimation();
    }
  }

  Future<void> _refreshPending() async {
    final pending = await OfflineQueueService.pendingCount();
    if (mounted) {
      setState(() => _pendingCount = pending);
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    final shouldShow = _isOffline || _pendingCount > 0;
    if (shouldShow) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  Future<void> _manualSync() async {
    if (_isSyncing || _isOffline) return;
    setState(() => _isSyncing = true);
    try {
      final result = await OfflineQueueService.sync();
      await _refreshPending();
      if (mounted && result.synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Synced ${result.synced} record${result.synced == 1 ? '' : 's'}'
              '${result.failed > 0 ? ', ${result.failed} failed' : ''}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _pollTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _heightAnim,
      axisAlignment: -1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: _isOffline
            ? Colors.orange.shade700
            : AppColors.primary.withValues(alpha: 0.92),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          bottom: false,
          child: Row(children: [
            Icon(
              _isOffline ? Icons.cloud_off : Icons.sync,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isOffline
                    ? 'You are offline${_pendingCount > 0 ? ' \u2014 $_pendingCount item${_pendingCount == 1 ? '' : 's'} pending sync' : ''}'
                    : '$_pendingCount item${_pendingCount == 1 ? '' : 's'} waiting to sync',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
            if (!_isOffline && _pendingCount > 0)
              GestureDetector(
                onTap: _manualSync,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isSyncing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Sync now',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
