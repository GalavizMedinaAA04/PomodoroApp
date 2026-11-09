import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoroapp/services/ciclo_pomodoro.dart';

void main() {
  final inicio = DateTime.utc(2026, 10, 20, 9);

  test('no inicia una fase de trabajo sin tarea', () {
    final ciclo = CicloPomodoro();

    expect(ciclo.iniciar(tareaId: null, ahora: inicio), isFalse);
    expect(ciclo.corriendo, isFalse);
  });

  test('la fase termina cuando pasa el tiempo real', () {
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
    ciclo.iniciar(tareaId: 'a', ahora: inicio);

    expect(ciclo.sincronizar(inicio.add(const Duration(minutes: 10))), isFalse);
    expect(ciclo.segundosRestantes, 15 * 60);
    expect(ciclo.sincronizar(inicio.add(const Duration(minutes: 25))), isTrue);
    expect(ciclo.segundosRestantes, 0);
  });

  test('pausar conserva el tiempo restante', () {
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
    ciclo.iniciar(tareaId: 'a', ahora: inicio);
    ciclo.pausar(inicio.add(const Duration(minutes: 5)));

    expect(ciclo.corriendo, isFalse);
    expect(ciclo.segundosRestantes, 20 * 60);
  });

  test('al terminar el trabajo devuelve la sesión y pasa a descanso', () {
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
    ciclo.iniciar(tareaId: 'tarea-1', ahora: inicio);
    ciclo.sincronizar(inicio.add(const Duration(minutes: 25)));

    final sesion = ciclo.finalizarFase();

    expect(sesion, isNotNull);
    expect(sesion!.tareaId, 'tarea-1');
    expect(sesion.minutos, 25);
    expect(ciclo.fase, FasePomodoro.descanso);
    expect(ciclo.segundosRestantes, 5 * 60);
    expect(ciclo.haySesionEnCurso, isFalse);
  });

  test('al terminar el descanso no devuelve sesión y vuelve a trabajo', () {
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
    ciclo.iniciar(tareaId: 'a', ahora: inicio);
    ciclo.sincronizar(inicio.add(const Duration(minutes: 25)));
    ciclo.finalizarFase();

    expect(ciclo.finalizarFase(), isNull);
    expect(ciclo.fase, FasePomodoro.trabajo);
  });

  test('cancelar descarta la sesión y restablece la fase de trabajo', () {
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
    ciclo.iniciar(tareaId: 'a', ahora: inicio);
    ciclo.cancelar();

    expect(ciclo.haySesionEnCurso, isFalse);
    expect(ciclo.segundosRestantes, 25 * 60);
  });

  test('aplicar tiempos no cambia nada mientras el reloj corre y aplica en la siguiente fase', () {
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
    ciclo.iniciar(tareaId: 'a', ahora: inicio);
    ciclo.aplicarTiempos(40, 10, 20, 3);

    expect(ciclo.minutosTrabajo, 25);

    ciclo.sincronizar(inicio.add(const Duration(minutes: 25)));
    final sesion = ciclo.finalizarFase();
    expect(sesion!.minutos, 25);
    expect(ciclo.minutosTrabajo, 40);
    expect(ciclo.minutosDescanso, 10);
    expect(ciclo.segundosRestantes, 10 * 60);
  });

  test('al completar los ciclos configurados prepara un descanso largo y reinicia el contador', () {
    final ciclo = CicloPomodoro(
      minutosTrabajo: 25,
      minutosDescanso: 5,
      minutosDescansoLargo: 15,
      ciclosAntesDeLargo: 4,
    );

    for (var i = 1; i <= 3; i++) {
      ciclo.iniciar(tareaId: 't1', ahora: inicio);
      ciclo.sincronizar(inicio.add(const Duration(minutes: 25)));
      ciclo.finalizarFase();
      expect(ciclo.esDescansoLargo, isFalse);
      expect(ciclo.segundosRestantes, 5 * 60);
      expect(ciclo.ciclosCompletados, i);
      ciclo.finalizarFase(); // termina el descanso corto
    }

    // 4.º ciclo de trabajo -> descanso largo de 15 min y contador vuelve a 0
    ciclo.iniciar(tareaId: 't1', ahora: inicio);
    ciclo.sincronizar(inicio.add(const Duration(minutes: 25)));
    ciclo.finalizarFase();

    expect(ciclo.fase, FasePomodoro.descanso);
    expect(ciclo.esDescansoLargo, isTrue);
    expect(ciclo.segundosRestantes, 15 * 60);
    expect(ciclo.ciclosCompletados, 0);
  });
}
