import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced API client for connecting to the Django backend.
///
/// Features:
/// - JSON GET/POST with optional Authorization header
/// - Multipart file uploads (for content uploads)
/// - Token persistence using SharedPreferences
class ApiService {
  ApiService._({required this.baseUrl});

  final String baseUrl;
  String? _token;

  static const _kTokenKey = 'coonch_access_token';
  static const _kLastActiveKey = 'coonch_last_active_ts';

  /// Async factory to create an ApiService and load persisted token.
  static Future<ApiService> create({required String baseUrl}) async {
    final s = ApiService._(baseUrl: baseUrl);
    await s._loadToken();
    return s;
  }

  /// Resolve a path or absolute URL into a Uri. If [path] is already a
  /// full URL (starts with http/https) it will be parsed directly so
  /// callers can use absolute endpoints returned by the server.
  Uri _resolveUri(String path) {
    final p = path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) {
      return Uri.parse(p);
    }
    return Uri.parse('$baseUrl$p');
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kTokenKey);
  }

  Future<void> markActiveNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastActiveKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<DateTime?> lastActiveAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_kLastActiveKey);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<bool> isInactiveLongerThan(Duration threshold) async {
    final last = await lastActiveAt();
    if (last == null) {
      await markActiveNow();
      return false;
    }
    final inactive = DateTime.now().difference(last);
    return inactive > threshold;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kLastActiveKey);
  }

  Future<void> logLogout() async {
    if (_token == null || _token!.isEmpty) return;
    try {
      await postJson('api/v1/user/logout/', {}, omitAuth: false);
    } catch (_) {
      // ignore logging failure to avoid blocking local logout
    }
  }

  Future<Map<String, dynamic>> blockUser(String userId) async {
    return await postJson('api/v1/user/block/$userId/', {}, omitAuth: false);
  }

  Future<Map<String, dynamic>> unblockUser(String userId) async {
    return await postJson('api/v1/user/unblock/$userId/', {}, omitAuth: false);
  }

  Map<String, String> _defaultHeaders({
    bool json = true,
    bool omitAuth = false,
  }) {
    final headers = <String, String>{};
    if (json) {
      // Explicit UTF-8 avoids mojibake for emoji and other Unicode text.
      headers['Content-Type'] = 'application/json; charset=utf-8';
      headers['Accept'] = 'application/json';
    }
    if (!omitAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool omitAuth = false,
  }) async {
    final uri = _resolveUri(path);
    final headers = _defaultHeaders(omitAuth: omitAuth);
    // Debug: log POST request details for troubleshooting 401s
    // ignore: avoid_print
    print('ApiService.postJson: POST $uri');
    // ignore: avoid_print
    print('ApiService.postJson: headers=$headers');
    // ignore: avoid_print
    print('ApiService.postJson: body=${jsonEncode(body)}');

    final res = await http.post(uri, headers: headers, body: jsonEncode(body));

    // Debug: log response status and body
    // ignore: avoid_print
    print('ApiService.postJson: status=${res.statusCode} body=${res.body}');

    return _process(res);
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final uri = _resolveUri(path);
    // Debug: log resolved URI for network troubleshooting
    // ignore: avoid_print
    print('ApiService.getJson: GET $uri');
    final res = await http.get(uri, headers: _defaultHeaders());
    // Debug: log response status and body
    // ignore: avoid_print
    print('ApiService.getJson: status=${res.statusCode} body=${res.body}');
    return _process(res);
  }

  /// Multipart POST for file uploads.
  /// [fields] are normal form fields, [fileField] is the name of the file field
  /// expected by the backend (e.g. "file"), and [file] is the file to upload.
  /// [onProgress] is a callback that receives the progress (0.0 to 1.0)
  Future<Map<String, dynamic>> postMultipart(
    String path,
    Map<String, String> fields, {
    String? fileField,
    File? file,
    String? filename,
    File? thumbnail,
    String thumbnailField = 'thumbnail',
    Function(double)? onProgress,
  }) async {
    final uri = _resolveUri(path);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_defaultHeaders(json: false));

    request.fields.addAll(fields);

    int totalBytes = 0;
    int sentBytes = 0;

    Stream<List<int>> track(Stream<List<int>> stream) {
      return stream.transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            sentBytes += data.length;
            if (onProgress != null && totalBytes > 0) {
              final progress = sentBytes / totalBytes;
              onProgress(progress.clamp(0.0, 1.0));
            }
            sink.add(data);
          },
        ),
      );
    }

    // Primary file (e.g., video or image)
    if (file != null && fileField != null) {
      final fileLength = await file.length();
      totalBytes += fileLength;
      final multipart = http.MultipartFile(
        fileField,
        http.ByteStream(track(file.openRead())),
        fileLength,
        filename: filename ?? file.path.split('/').last,
      );
      request.files.add(multipart);
    }

    // Optional thumbnail (for videos/shorts)
    if (thumbnail != null) {
      final thumbLength = await thumbnail.length();
      totalBytes += thumbLength;
      final multipart = http.MultipartFile(
        thumbnailField,
        http.ByteStream(track(thumbnail.openRead())),
        thumbLength,
        filename: thumbnail.path.split('/').last,
      );
      request.files.add(multipart);
    }

    if (onProgress != null && totalBytes > 0) {
      onProgress(0.0);
    }

    try {
      // Send request and get response
      final streamed = await request.send().timeout(
        const Duration(minutes: 10),
      );
      final res = await http.Response.fromStream(streamed);

      if (onProgress != null) {
        onProgress(1.0); // Complete
      }

      return _process(res);
    } catch (e) {
      rethrow;
    }
  }

  /// Generic multipart request that allows custom HTTP method (e.g., PATCH).
  /// Useful for endpoints that accept multipart PATCH (profile update with avatar).
  Future<Map<String, dynamic>> patchMultipart(
    String path,
    Map<String, String> fields, {
    String? fileField,
    File? file,
    String? filename,
    File? thumbnail,
    String thumbnailField = 'thumbnail',
  }) async {
    final uri = _resolveUri(path);
    // http.MultipartRequest accepts any method string
    final request = http.MultipartRequest('PATCH', uri);
    request.headers.addAll(_defaultHeaders(json: false));

    request.fields.addAll(fields);

    if (file != null && fileField != null) {
      final stream = http.ByteStream(file.openRead());
      final length = await file.length();
      final multipart = http.MultipartFile(
        fileField,
        stream,
        length,
        filename: filename ?? file.path.split('/').last,
      );
      request.files.add(multipart);
    }

    if (thumbnail != null) {
      final stream = http.ByteStream(thumbnail.openRead());
      final length = await thumbnail.length();
      final multipart = http.MultipartFile(
        thumbnailField,
        stream,
        length,
        filename: thumbnail.path.split('/').last,
      );
      request.files.add(multipart);
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _process(res);
  }

  Map<String, dynamic> _process(http.Response res) {
    final rawBody = res.bodyBytes.isEmpty
        ? ''
        : utf8.decode(res.bodyBytes, allowMalformed: true);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (rawBody.isEmpty) return {};
      try {
        return jsonDecode(rawBody) as Map<String, dynamic>;
      } catch (e) {
        // If backend returns non-JSON success, return raw string
        return {'success': 1, 'message': rawBody};
      }
    }
    // Try to decode error body to provide a clearer message
    try {
      final parsed = jsonDecode(rawBody);
      // If parsed is a map, stringify in a readable form
      if (parsed is Map) return parsed.cast<String, dynamic>();
      // Otherwise include it in an error wrapper
      throw ApiException(res.statusCode, parsed.toString());
    } catch (e) {
      // Try a lenient replacement (single quotes -> double quotes)
      try {
        final cleaned = rawBody.replaceAll("'", '"');
        final parsed = jsonDecode(cleaned);
        if (parsed is Map) return parsed.cast<String, dynamic>();
        throw ApiException(res.statusCode, parsed.toString());
      } catch (_) {
        // Fallback: throw with raw body
        throw ApiException(res.statusCode, rawBody);
      }
    }
  }

  // --- High-level helpers mapped to the Django API ---

  /// Register a new user. Payload should include username, email, password, phone.
  /// On success, if a token is returned it will be persisted automatically.
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String otp,
    String phone = '',
  }) async {
    final body = {
      'username': username,
      'email': email,
      'password': password,
      'phone': phone,
      'otp': otp,
    };

    final res = await postJson('api/v1/auth/register/', body, omitAuth: true);

    // Persist token if provided in response data
    try {
      final token = (res['data'] ?? {})['token'] as String?;
      if (token != null && token.isNotEmpty) await setToken(token);
    } catch (_) {}

    return res;
  }

  /// Request an OTP for registration to verify the user's email.
  Future<Map<String, dynamic>> requestRegistrationOtp(String email) async {
    return await postJson('api/v1/auth/register/send-otp/', {
      'email': email,
    }, omitAuth: true);
  }

  /// Login using either the /user/login/ or /auth/login/ endpoint.
  /// On success persists token automatically.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    Future<Map<String, dynamic>> send(String path) async {
      return await postJson(path, {
        'username': username,
        'email': username,
        'password': password,
      }, omitAuth: true);
    }

    Future<void> persistTokenIfPresent(Map<String, dynamic> res) async {
      String? token;
      try {
        token = (res['data'] ?? {})['token'] as String?;
      } catch (_) {}

      // Some JWT endpoints may return `access` directly.
      token ??= res['access'] as String?;

      if (token != null && token.isNotEmpty) {
        await setToken(token);
      }
    }

    bool hasSuccessEnvelope(Map<String, dynamic> res) =>
        res.containsKey('success');

    bool isSuccess(Map<String, dynamic> res) {
      if (res['success'] == 1 || res['success'] == true) return true;
      final directAccess = res['access'];
      return directAccess is String && directAccess.isNotEmpty;
    }

    // Prefer user/login path.
    final primary = await send('api/v1/user/login/');
    if (isSuccess(primary)) {
      await persistTokenIfPresent(primary);
      return primary;
    }

    // If the primary response isn't in the expected API envelope,
    // try the auth/login fallback endpoint.
    if (!hasSuccessEnvelope(primary)) {
      final fallback = await send('api/v1/auth/login/');
      if (isSuccess(fallback)) {
        await persistTokenIfPresent(fallback);
      }
      return fallback;
    }

    return primary;
  }

  /// Get profile by id (public profile)
  Future<Map<String, dynamic>> getProfileById(String id) async {
    return await getJson('api/v1/user/profile/$id/');
  }

  /// Update current user's profile (PATCH)
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await http.patch(
      _resolveUri('api/v1/user/update-profile/'),
      headers: _defaultHeaders(),
      body: jsonEncode(data),
    );
    return _process(res);
  }

  /// Update current user's profile with support for uploading avatar image.
  /// If [avatar] is provided the request will be sent as multipart PATCH.
  Future<Map<String, dynamic>> updateProfileMultipart(
    Map<String, String> fields, {
    File? avatar,
    String avatarField = 'avatar',
  }) async {
    if (avatar != null) {
      return await patchMultipart(
        'api/v1/user/update-profile/',
        fields,
        fileField: avatarField,
        file: avatar,
      );
    }
    // Fallback to JSON PATCH
    return await updateProfile(fields.map((k, v) => MapEntry(k, v)));
  }

  /// Update password
  Future<Map<String, dynamic>> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final res = await http.patch(
      _resolveUri('api/v1/user/update-password/'),
      headers: _defaultHeaders(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    return _process(res);
  }

  /// Request a forgot-password OTP (email-based).
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    return await postJson('api/v1/user/forgot-password/', {'email': email});
  }

  /// Confirm forgot-password using email + otp to set a new password.
  Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String otp,
    required String password,
  }) async {
    return await postJson('api/v1/user/forgot-password/confirm/', {
      'email': email,
      'otp': otp,
      'password': password,
    });
  }

  /// Request an OTP for account deletion.
  Future<Map<String, dynamic>> requestDeleteAccountOtp() async {
    return await postJson('api/v1/user/delete-account/send-otp/', {});
  }

  /// Delete the authenticated user's account using an OTP verification.
  /// Expects backend endpoint to soft-delete and revoke tokens.
  Future<Map<String, dynamic>> deleteAccount(String otp) async {
    return await postJson('api/v1/user/delete-account/', {'otp': otp});
  }

  /// Set user categories
  Future<Map<String, dynamic>> setCategories(List<int> categoryIds) async {
    return await postJson('api/v1/user/categories/', {
      'categories': categoryIds,
    });
  }

  /// Follow a user by id
  Future<Map<String, dynamic>> followUser(String id) async {
    // Call the follow endpoint then attempt to re-fetch the target's
    // profile so callers receive the authoritative user state
    final res = await postJson('api/v1/user/follow/$id/', {});
    try {
      final profile = await getProfileById(id);
      return profile;
    } catch (_) {
      return res;
    }
  }

  /// Unfollow a user by id
  Future<Map<String, dynamic>> unfollowUser(String id) async {
    final res = await postJson('api/v1/user/unfollow/$id/', {});
    try {
      final profile = await getProfileById(id);
      return profile;
    } catch (_) {
      return res;
    }
  }

  /// Get followers
  Future<Map<String, dynamic>> getFollowers() async {
    return await getJson('api/v1/user/followers/');
  }

  /// Get followers for a specific user id (public). Returns the API payload
  /// - If the backend returns a `data` list it will be returned, otherwise
  /// the raw response map is returned and callers can extract fields.
  Future<List<dynamic>> getFollowersFor(String userId) async {
    final res = await getJson(
      'api/v1/user/followers/?user_id=${Uri.encodeComponent(userId)}',
    );
    if (res.containsKey('data') && res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    if (res['results'] is List) return res['results'] as List<dynamic>;
    // Some backends return a direct list
    if (res is List) return res as List<dynamic>;
    return [];
  }

  /// Get followings for a specific user id (public).
  Future<List<dynamic>> getFollowingsFor(String userId) async {
    final res = await getJson(
      'api/v1/user/followings/?user_id=${Uri.encodeComponent(userId)}',
    );
    if (res.containsKey('data') && res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    if (res['results'] is List) return res['results'] as List<dynamic>;
    if (res is List) return res as List<dynamic>;
    return [];
  }

  /// Search users
  Future<List<dynamic>> searchUsers(String searchText) async {
    final res = await getJson(
      'api/v1/user/search/?search_text=${Uri.encodeComponent(searchText)}',
    );
    if (res['data'] is List) return res['data'] as List<dynamic>;
    return [];
  }

  /// Get categories list
  Future<List<dynamic>> getCategories() async {
    // Debug: log categories fetch
    // ignore: avoid_print
    print('ApiService.getCategories: fetching categories');
    // Some deployments expose categories under the content route. Use the
    // content-based path which is present in the project's router.
    final res = await getJson('api/v1/content/categories/');
    if (res['data'] is List) return res['data'] as List<dynamic>;
    if (res['data'] is Map && res['data']['results'] is List) {
      return res['data']['results'] as List<dynamic>;
    }
    return [];
  }

  /// Get notifications for the current user.
  /// Returns a list of notification objects (tries `data`, then `results`).
  Future<List<dynamic>> getNotifications() async {
    // Server notifications endpoint lives under /user/ in this backend.
    final res = await getJson('api/v1/user/notifications/');
    if (res.containsKey('data') && res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    if (res.containsKey('results') && res['results'] is List) {
      return res['results'] as List<dynamic>;
    }
    if (res is List) return res as List<dynamic>;
    return [];
  }

  /// Mark notifications as read. If [ids] is null or empty, marks all for user.
  Future<Map<String, dynamic>> markNotificationsRead({
    List<String>? ids,
  }) async {
    final body = <String, dynamic>{};
    if (ids != null) body['ids'] = ids;
    return await postJson('api/v1/user/notifications/mark-read/', body);
  }

  /// Get unread notifications count (includes pending follow requests).
  Future<int> getUnreadNotificationsCount() async {
    try {
      final res = await getJson('api/v1/user/notifications/unread-count/');
      if (res.containsKey('data') &&
          res['data'] is Map &&
          res['data']['count'] != null) {
        return int.tryParse(res['data']['count'].toString()) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Convenience: return the number of notifications (client-side count).
  /// This currently fetches the notifications list and returns its length.
  Future<int> getNotificationsCount() async {
    final list = await getNotifications();
    return list.length;
  }

  /// Create a follow request targeting the user with [id].
  Future<Map<String, dynamic>> createFollowRequest(String id) async {
    final res = await postJson('api/v1/user/follow-request/$id/', {});
    try {
      // Re-fetch the target profile to get authoritative is_requested flag
      final profile = await getProfileById(id);
      return profile;
    } catch (_) {
      return res;
    }
  }

  /// Accept a follow request by id.
  Future<Map<String, dynamic>> acceptFollowRequest(String requestId) async {
    return await postJson('api/v1/user/follow-requests/$requestId/accept/', {});
  }

  /// Reject a follow request by id.
  Future<Map<String, dynamic>> rejectFollowRequest(String requestId) async {
    return await postJson('api/v1/user/follow-requests/$requestId/reject/', {});
  }

  /// Create content (supports multipart uploads when file is provided)
  /// Create content (supports multipart uploads when file is provided)
  /// If uploading a video/short, pass [thumbnail] to include the required
  /// thumbnail image in the multipart payload.
  /// [onProgress] is a callback that receives the upload progress (0.0 to 1.0)
  Future<Map<String, dynamic>> createContent(
    Map<String, String> fields, {
    File? file,
    String? fileField,
    File? thumbnail,
    Function(double)? onProgress,
  }) async {
    if (file != null) {
      return await postMultipart(
        'api/v1/content/',
        fields,
        fileField: fileField ?? 'file',
        file: file,
        thumbnail: thumbnail,
        onProgress: onProgress,
      );
    }
    return await postJson(
      'api/v1/content/',
      fields.map((k, v) => MapEntry(k, v)),
    );
  }

  /// Get all draft contents created by current user.
  Future<List<dynamic>> getDraftContents() async {
    final res = await getJson('api/v1/content/drafts/');
    if (res.containsKey('data') && res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    if ((res['success'] != null && res['success'] != 1) ||
        res.containsKey('detail') ||
        res.containsKey('error')) {
      throw ApiException(
        500,
        res['detail']?.toString() ??
            res['message']?.toString() ??
            'Failed to load drafts',
      );
    }
    return [];
  }

  /// Publish one draft by content id.
  Future<Map<String, dynamic>> publishDraft(String contentId) async {
    return await postJson('api/v1/content/$contentId/publish/', {});
  }

  /// Publish all drafts in one click.
  Future<Map<String, dynamic>> publishAllDrafts() async {
    return await postJson('api/v1/content/publish-all-drafts/', {});
  }

  /// Like or unlike content
  Future<Map<String, dynamic>> likeUnlikeContent(String contentId) async {
    // Some backends register the action route with a hyphen (like-unlike)
    // while others may keep the underscore (like_unlike). Try the
    // hyphenated path first and fall back to the underscore path on 404.
    try {
      return await postJson('api/v1/content/$contentId/like-unlike/', {});
    } catch (e) {
      if (e is ApiException && e.code == 404) {
        // Retry using underscore variant
        return await postJson('api/v1/content/$contentId/like_unlike/', {});
      }
      rethrow;
    }
  }

  /// Comment on content
  Future<Map<String, dynamic>> commentContent(
    String contentId,
    String comment,
  ) async {
    final res = await postJson('api/v1/content/$contentId/comment/', {
      'comment_text': comment,
    });
    if (res['success'] == 0 || res['success'] == false) {
      throw ApiException(
        res['error_code'] ?? 400,
        res['message'] ?? 'Comment failed',
      );
    }
    return res;
  }

  /// Report content for moderation review.
  Future<Map<String, dynamic>> reportContent(
    String contentId, {
    required String reason,
    String? details,
  }) async {
    final payload = <String, dynamic>{'reason': reason};
    if (details != null && details.trim().isNotEmpty) {
      payload['details'] = details.trim();
    }
    return await postJson('api/v1/content/$contentId/report/', payload);
  }

  /// Delete a comment
  Future<Map<String, dynamic>> deleteComment(
    String contentId,
    String commentId,
  ) async {
    final res = await http.delete(
      _resolveUri('api/v1/content/$contentId/comment/$commentId/'),
      headers: _defaultHeaders(),
    );
    return _process(res);
  }

  /// Edit a comment's text.
  Future<Map<String, dynamic>> updateComment(
    String contentId,
    String commentId,
    String comment,
  ) async {
    final res = await http.patch(
      _resolveUri('api/v1/content/$contentId/comment/$commentId/'),
      headers: _defaultHeaders(),
      body: jsonEncode({'comment_text': comment}),
    );
    return _process(res);
  }

  /// Get current authenticated user's profile.
  Future<Map<String, dynamic>> getProfile() async {
    final res = await getJson('api/v1/user/profile/');
    return res;
  }

  /// Get content list. Returns the `data` array from the API response when present.
  Future<List<dynamic>> getContents({Map<String, String>? queryParams}) async {
    final path = StringBuffer('api/v1/content/');
    if (queryParams != null && queryParams.isNotEmpty) {
      final qs = queryParams.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
      path.write('?$qs');
    }

    final res = await getJson(path.toString());
    if (res.containsKey('data') && res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    // Some endpoints return object with pagination; try to extract 'results'
    if (res.containsKey('data') &&
        res['data'] is Map &&
        res['data']['results'] is List) {
      return res['data']['results'] as List<dynamic>;
    }
    return [];
  }

  /// Convenience: fetch stories (content with type=story). Caller can pass
  /// additional query params (e.g., user_id) to scope results.
  Future<List<dynamic>> getStories({Map<String, String>? queryParams}) async {
    final q = <String, String>{'type': 'story'};
    if (queryParams != null) q.addAll(queryParams);
    return await getContents(queryParams: q);
  }

  /// Register a view for a content/story (best-effort). Some backends
  /// implement `POST /api/v1/content/<id>/view/` to record views. This method
  /// will try that endpoint and ignore 404s (best-effort).
  Future<Map<String, dynamic>> viewContent(String contentId) async {
    try {
      return await postJson('api/v1/content/$contentId/view/', {});
    } catch (e) {
      // If backend doesn't support it (404), ignore silently.
      if (e is ApiException && e.code == 404) return {'success': 0};
      rethrow;
    }
  }

  /// Get a single content item by id.
  Future<Map<String, dynamic>> getContentById(String id) async {
    final res = await getJson('api/v1/content/$id/');
    if (res['success'] == 1 && res['data'] is Map) {
      return res['data'] as Map<String, dynamic>;
    }
    // If API returns the object directly
    return res;
  }

  /// Get series list. Returns the `data` array from the API response.
  Future<List<dynamic>> getSeries({Map<String, String>? queryParams}) async {
    final path = StringBuffer('api/v1/content/series/');
    if (queryParams != null && queryParams.isNotEmpty) {
      final qs = queryParams.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
      path.write('?$qs');
    }

    final res = await getJson(path.toString());
    if (res.containsKey('data') && res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    return [];
  }

  /// Get a single series by id with all its items.
  Future<Map<String, dynamic>> getSeriesById(String id) async {
    final res = await getJson('api/v1/content/series/$id/');
    if (res['success'] == 1 && res['data'] is Map) {
      return res['data'] as Map<String, dynamic>;
    }
    return res;
  }

  /// Get series items for a series.
  Future<List<dynamic>> getSeriesItems(String seriesId) async {
    final series = await getSeriesById(seriesId);
    if (series.containsKey('items') && series['items'] is List) {
      return series['items'] as List<dynamic>;
    }
    return [];
  }

  /// Delete a content item by id.
  /// Calls `DELETE /api/v1/content/<id>/` and returns the parsed response.
  Future<Map<String, dynamic>> deleteContent(String id) async {
    final res = await http.delete(
      _resolveUri('api/v1/content/$id/'),
      headers: _defaultHeaders(),
    );
    return _process(res);
  }

  /// Update a content item (PATCH). If [file] is provided the request will
  /// be sent as multipart PATCH, otherwise a JSON PATCH is sent.
  Future<Map<String, dynamic>> updateContent(
    String id,
    Map<String, String> fields, {
    File? file,
    String? fileField,
    File? thumbnail,
  }) async {
    if (file != null) {
      return await patchMultipart(
        'api/v1/content/$id/',
        fields,
        fileField: fileField ?? 'file',
        file: file,
        thumbnail: thumbnail,
      );
    }
    final res = await http.patch(
      _resolveUri('api/v1/content/$id/'),
      headers: _defaultHeaders(),
      body: jsonEncode(fields),
    );
    return _process(res);
  }

  /// Update a series (PATCH). Use this for editing title/description/external_id.
  Future<Map<String, dynamic>> updateSeries(
    String id,
    Map<String, String> fields,
  ) async {
    final res = await http.patch(
      _resolveUri('api/v1/content/series/$id/'),
      headers: _defaultHeaders(),
      body: jsonEncode(fields),
    );
    return _process(res);
  }

  /// Delete a series by id.
  Future<Map<String, dynamic>> deleteSeries(String id) async {
    final res = await http.delete(
      _resolveUri('api/v1/content/series/$id/'),
      headers: _defaultHeaders(),
    );
    return _process(res);
  }

  /// Get available subscription plans
  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    final res = await http.get(
      _resolveUri('api/v1/rewards/plans/'),
      headers: _defaultHeaders(),
    );
    final data = _process(res);
    return (data['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Get user's current subscription status
  Future<Map<String, dynamic>> getMySubscription() async {
    final res = await http.get(
      _resolveUri('api/v1/rewards/my-subscription/'),
      headers: _defaultHeaders(),
    );
    return _process(res);
  }

  /// Create Stripe payment intent for a subscription plan.
  Future<Map<String, dynamic>> createSubscriptionPaymentIntent(
    int planId,
  ) async {
    final res = await http.post(
      _resolveUri('api/v1/rewards/create-subscription-intent/'),
      headers: _defaultHeaders(),
      body: jsonEncode({'plan_id': planId}),
    );
    return _process(res);
  }

  /// Confirm and activate a paid subscription plan.
  Future<Map<String, dynamic>> subscribeToPlan(
    int planId, {
    required String paymentIntentId,
    String? paymentMethodId,
  }) async {
    final res = await http.post(
      _resolveUri('api/v1/rewards/subscribe/'),
      headers: _defaultHeaders(),
      body: jsonEncode({
        'plan_id': planId,
        'payment_intent_id': paymentIntentId,
        if (paymentMethodId != null && paymentMethodId.isNotEmpty)
          'payment_method_id': paymentMethodId,
      }),
    );
    return _process(res);
  }

  /// Check if user can access specific content
  Future<Map<String, dynamic>> checkContentAccess(String contentId) async {
    final res = await http.get(
      _resolveUri('api/v1/rewards/check-access/?content_id=$contentId'),
      headers: _defaultHeaders(),
    );
    return _process(res);
  }

  /// Track ad view for infotainment content
  Future<Map<String, dynamic>> trackAdView(String contentId) async {
    final res = await http.post(
      _resolveUri('api/v1/rewards/ad-view/'),
      headers: _defaultHeaders(),
      body: jsonEncode({'content_id': contentId}),
    );
    return _process(res);
  }

  /// Get creator's earnings from ad views
  Future<Map<String, dynamic>> getCreatorEarnings() async {
    final res = await http.get(
      _resolveUri('api/v1/rewards/earnings/'),
      headers: _defaultHeaders(),
    );
    return _process(res);
  }
}

class ApiException implements Exception {
  ApiException(this.code, this.body);
  final int code;
  final String body;

  @override
  String toString() => 'ApiException(code: $code, body: $body)';
}
