import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/follow_service.dart';
import 'user_profile_page.dart';

enum FollowListType { followers, following }

class FollowListPage extends StatefulWidget {
  final String uid;
  final String username;
  final FollowListType listType;

  const FollowListPage({
    super.key,
    required this.uid,
    required this.username,
    required this.listType,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  final FollowService _followService = FollowService();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    List<String> uids;
    if (widget.listType == FollowListType.followers) {
      uids = await _followService.getFollowers(widget.uid);
    } else {
      uids = await _followService.getFollowing(widget.uid);
    }

    final users = await _databaseService.getUsersByIds(uids);

    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  void _navigateToProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.listType == FollowListType.followers
        ? 'Followers'
        : 'Following';

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.username,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF29F05)),
            )
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.listType == FollowListType.followers
                            ? Icons.people_outline
                            : Icons.person_add_outlined,
                        size: 64,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.listType == FollowListType.followers
                            ? 'No followers yet'
                            : 'Not following anyone yet',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      onTap: () => _navigateToProfile(user),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF333333),
                        backgroundImage: user.profilePictureUrl != null
                            ? NetworkImage(user.profilePictureUrl!)
                            : null,
                        child: user.profilePictureUrl == null
                            ? const Icon(Icons.person,
                                color: Colors.grey, size: 28)
                            : null,
                      ),
                      title: Text(
                        user.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        user.fullName,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right,
                          color: Colors.grey[600], size: 20),
                    );
                  },
                ),
    );
  }
}
