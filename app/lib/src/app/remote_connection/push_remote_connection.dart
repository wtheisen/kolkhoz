import 'remote_connection.dart';

class PushRemoteConnection {
  const PushRemoteConnection(this._remote);

  final RemoteConnection _remote;

  Future<void> registerInstallation({
    required String installationID,
    required String platform,
    required String token,
  }) async {
    await _remote.requestJson(
      method: 'PUT',
      path: 'installations/$installationID',
      body: {
        'platform': platform,
        'token': token,
        'preferences': {
          'social': true,
          'invites': true,
          'turns': true,
          'results': true,
        },
      },
    );
  }

  Future<void> deleteInstallation(String installationID) async {
    await _remote.request(
      method: 'DELETE',
      path: 'installations/$installationID',
    );
  }
}
