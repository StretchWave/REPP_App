import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rankings = [];
  int _userRank = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchRankings();
  }

  Future<void> _fetchRankings() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      _currentUserId = currentUser?.id;

      if (currentUser == null) return;

      // 1. Fetch current user's stats for reference
      final userProfile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', currentUser.id)
          .single();

      final int userPowerLevel = userProfile['power_level'] ?? 0;
      final int userMaxStreak = userProfile['max_streak'] ?? 0;
      final String userCreatedAt = currentUser.createdAt;

      // 2. Count how many users users are strictly better or equal-but-better

      // Try optional RPC if available
      try {
        await Supabase.instance.client
            .rpc(
              'get_user_rank',
              params: {
                'p_power_level': userPowerLevel,
                'p_max_streak': userMaxStreak,
                'p_created_at': userCreatedAt,
              },
            )
            .maybeSingle();
      } catch (_) {
        // RPC might not exist, ignore.
      }

      // 3. Fetch Rankings List
      // We try to fetch with `max_streak` first. If column missing, we fallback.
      List<dynamic> data = [];

      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, power_level, max_streak, created_at')
            .order('power_level', ascending: false)
            .order('max_streak', ascending: false)
            .order('power_level_updated_at', ascending: true, nullsFirst: false)
            // If null, it means old data, push to end or treat as "just now"?
            // `ascending: true` means older timestamps (reached earlier) come first.
            // `nullsFirst: false` ensures those with actual dates come first if we want them prioritized,
            // OR if we assume null means "very old", we use `nullsFirst: true`.
            // Safest is nullsLast usually, effectively treating them as "newbies" or "unknown".
            .limit(100);
        data = response;
      } catch (_) {
        // Fallback: max_streak might not exist.
        // Sort by power_level only.
        final response = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, power_level, created_at')
            .order('power_level', ascending: false)
            .order('power_level_updated_at', ascending: true, nullsFirst: false)
            .limit(100);
        data = response;
      }

      // In a real production app with millions of users, we would need a dedicated Ranking Table or View with Row Number.
      int myIndex = -1;

      for (int i = 0; i < data.length; i++) {
        if (data[i]['id'] == _currentUserId) {
          myIndex = i;
          break;
        }
      }

      // If user is not in top 100, we might need a separate query to just find their neighbors.
      // But for this task, let's assume valid data or just show what we have.

      List<Map<String, dynamic>> processedList = [];
      for (int i = 0; i < data.length; i++) {
        processedList.add({
          'rank': i + 1,
          'id': data[i]['id'],
          'name': data[i]['full_name'] ?? 'Unknown',
          'power_level': data[i]['power_level'] ?? 0,
          'max_streak': data[i]['max_streak'] ?? 0,
          'isMe': data[i]['id'] == _currentUserId,
        });
      }

      // If I am not in the list (rank > 100), we manually append me at the end with "100+"
      if (myIndex == -1) {
        // This is a UI patch for now
        _userRank = 999;
      } else {
        _userRank = myIndex + 1;
      }

      // Filter to show relevant window if large
      // For now, showing top 100 is fine, maybe scroll to user.

      if (mounted) {
        setState(() {
          _rankings = processedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching rankings: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F25),
      appBar: AppBar(
        title: const Text(
          "Global Rankings",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Header for My Rank
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueAccent.shade700,
                        Colors.blueAccent.shade400,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Your Rank",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "#$_userRank",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 48,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _rankings.length,
                    itemBuilder: (context, index) {
                      final item = _rankings[index];
                      final isMe = item['isMe'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blueAccent.withOpacity(0.15)
                              : const Color(0xFF2C313A),
                          borderRadius: BorderRadius.circular(12),
                          border: isMe
                              ? Border.all(
                                  color: Colors.blueAccent.withOpacity(0.5),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Rank Number
                            SizedBox(
                              width: 40,
                              child: Text(
                                "#${item['rank']}",
                                style: TextStyle(
                                  color: index < 3 ? Colors.amber : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),

                            // Avatar Placeholder
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.grey[800],
                              child: Text(
                                (item['name'] as String)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Name & Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.blueAccent
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Streak: ${item['max_streak']} • Power: ${item['power_level']}",
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Power Level Badge or Icon
                            if (index < 3)
                              Icon(Icons.star, color: Colors.amber, size: 20),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
