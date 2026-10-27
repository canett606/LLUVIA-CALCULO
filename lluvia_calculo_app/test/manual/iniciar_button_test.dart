import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lluvia_calculo/providers/game_provider.dart';
import 'package:lluvia_calculo/services/storage_service.dart';
import 'package:lluvia_calculo/services/audio_service.dart';
import 'package:lluvia_calculo/services/multiplayer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startGame sin perfil crea invitado y arranca', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final provider = GameProvider(
      storage: storage,
      audio: AudioService(),
      multiplayer: MultiplayerServiceFactory.create(),
    );
    // No llamar initialize() (audioplayers rompe en test); marcar storage listo
    expect(provider.hasPlayer, isFalse);
    provider.startGame();
    expect(provider.hasPlayer, isTrue);
    expect(provider.state.isRunning, isTrue);
    expect(provider.state.activeDrops, isNotEmpty);
    provider.dispose();
  });
}
