import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';

import 'user_id_storage.dart';

class PresenceService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static RealtimeChannel? _presenceChannel;
  static String? _currentUserKey;
  static bool _isStarting = false;
  static final Set<Function(Set<String>)> _listeners = {};

  /// Ensures the current user is tracked on the presence channel so that other
  /// users can see their online indicator regardless of which page they're on.
  static Future<void> ensureTrackingStarted() async {
    if (_isStarting) return;

    final userId = await UserIdStorage.getLoggedInUserId();
    final userKey = userId?.toString();

    if (userKey == null || userKey.isEmpty) {
      log('PresenceService: No logged-in user ID available');
      return;
    }

    if (_presenceChannel != null && _currentUserKey == userKey) {
      // Already tracking this user.
      return;
    }

    _isStarting = true;
    await stopTracking();

    try {
      final channel = _supabase.channel(
        'presence:online_users',
        opts: RealtimeChannelConfig(
          key: userKey,
        ),
      );

      // Set up presence listeners to notify subscribers
      channel
        ..onPresenceSync((_) => _notifyListeners(channel))
        ..onPresenceJoin((_) => _notifyListeners(channel))
        ..onPresenceLeave((_) => _notifyListeners(channel));

      await channel.subscribe();
      await channel.track({
        'user_id': userKey,
        'last_seen_at': DateTime.now().toIso8601String(),
      });

      _presenceChannel = channel;
      _currentUserKey = userKey;
      log('PresenceService: Started tracking user $userKey');
      
      // Notify listeners with initial state
      _notifyListeners(channel);
    } catch (e) {
      log('PresenceService: Error starting presence tracking - $e');
    } finally {
      _isStarting = false;
    }
  }

  /// Notifies all listeners of the current presence state
  static void _notifyListeners(RealtimeChannel channel) {
    final presenceStates = channel.presenceState();
    final Set<String> onlineKeys = presenceStates
        .where((state) => state.presences.isNotEmpty)
        .map((state) => state.key)
        .toSet();
    
    for (final listener in _listeners) {
      try {
        listener(onlineKeys);
      } catch (e) {
        log('PresenceService: Error notifying listener - $e');
      }
    }
  }

  /// Gets the current set of online user keys
  static Set<String> getOnlineUserKeys() {
    if (_presenceChannel == null) return {};
    
    final presenceStates = _presenceChannel!.presenceState();
    return presenceStates
        .where((state) => state.presences.isNotEmpty)
        .map((state) => state.key)
        .toSet();
  }

  /// Adds a listener that will be called whenever presence state changes
  static void addPresenceListener(Function(Set<String>) listener) {
    _listeners.add(listener);
    // Immediately notify with current state
    if (_presenceChannel != null) {
      listener(getOnlineUserKeys());
    }
  }

  /// Removes a presence listener
  static void removePresenceListener(Function(Set<String>) listener) {
    _listeners.remove(listener);
  }

  /// Stops tracking the current user on the presence channel.
  static Future<void> stopTracking() async {
    if (_presenceChannel == null) return;

    try {
      await _presenceChannel!.untrack();
    } catch (e) {
      log('PresenceService: Error untracking presence - $e');
    }

    try {
      await _presenceChannel!.unsubscribe();
    } catch (e) {
      log('PresenceService: Error unsubscribing presence channel - $e');
    }

    _presenceChannel = null;
    _currentUserKey = null;
    _listeners.clear();
  }
}


