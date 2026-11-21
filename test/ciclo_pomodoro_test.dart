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

  test('CP-TD-02 cancelar sin haber iniciado', () {
    // Preparar
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);

    // Ejecutar
    ciclo.cancelar();

    // Verificar
    expect(ciclo.fase, FasePomodoro.trabajo);
    expect(ciclo.segundosRestantes, 25 * 60);
    expect(ciclo.haySesionEnCurso, isFalse);
  });

  test(
    'CP-TD-03 iniciar un trabajo de 25 min con tarea, dejar que termine, finalizar la fase, iniciar el descanso y cancelar',
    () {
      // Preparar
      final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
      ciclo.iniciar(tareaId: 'tarea-1', ahora: inicio);
      ciclo.sincronizar(inicio.add(const Duration(minutes: 25)));
      ciclo.finalizarFase();
      ciclo.iniciar(
        tareaId: null,
        ahora: inicio.add(const Duration(minutes: 25)),
      );

      // Ejecutar
      ciclo.cancelar();

      // Verificar
      expect(ciclo.fase, FasePomodoro.trabajo);
      expect(ciclo.segundosRestantes, 25 * 60);
      expect(ciclo.esDescansoLargo, isFalse);
    },
  );

  test(
    'CP-ES-07 iniciar, pausar a los 5 min, esperar 25 min en pausa y reanudar',
    () {
      // Preparar
      final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
      ciclo.iniciar(tareaId: 'tarea-1', ahora: inicio);
      final tPausa = inicio.add(const Duration(minutes: 5));
      ciclo.pausar(tPausa);
      final tReanudar = tPausa.add(const Duration(minutes: 25));

      // Ejecutar
      ciclo.iniciar(tareaId: 'tarea-1', ahora: tReanudar);
      final terminoA19 = ciclo.sincronizar(
        tReanudar.add(const Duration(minutes: 19)),
      );
      final restantesA19 = ciclo.segundosRestantes;
      final terminoA20 = ciclo.sincronizar(
        tReanudar.add(const Duration(minutes: 20)),
      );

      // Verificar
      expect(terminoA19, isFalse);
      expect(restantesA19, 1 * 60);
      expect(terminoA20, isTrue);
      expect(ciclo.segundosRestantes, 0);
    },
  );

  test('CP-CB-02 llamar a finalizarFase en un trabajo que nunca inició', () {
    // Preparar
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);

    // Ejecutar
    final sesion = ciclo.finalizarFase();

    // Verificar
    expect(sesion, isNull);
    expect(ciclo.fase, FasePomodoro.descanso);
  });

  test('CP-ES-08 iniciar el descanso, pausarlo y reanudarlo', () {
    // Preparar
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
    ciclo.iniciar(tareaId: 'tarea-1', ahora: inicio);
    ciclo.sincronizar(inicio.add(const Duration(minutes: 25)));
    ciclo.finalizarFase();
    final inicioDescanso = inicio.add(const Duration(minutes: 25));
    ciclo.iniciar(tareaId: null, ahora: inicioDescanso);

    // Ejecutar
    final tPausa = inicioDescanso.add(const Duration(minutes: 2));
    ciclo.pausar(tPausa);
    final restantesEnPausa = ciclo.segundosRestantes;
    final tReanudar = tPausa.add(const Duration(minutes: 10));
    ciclo.iniciar(tareaId: null, ahora: tReanudar);
    final terminoAntes = ciclo.sincronizar(
      tReanudar.add(const Duration(minutes: 2)),
    );
    final terminoAlFinal = ciclo.sincronizar(
      tReanudar.add(const Duration(minutes: 3)),
    );

    // Verificar
    expect(restantesEnPausa, 3 * 60);
    expect(terminoAntes, isFalse);
    expect(terminoAlFinal, isTrue);
    expect(ciclo.segundosRestantes, 0);
  });

  test('CP-ES-09 iniciar un trabajo, pausarlo y cancelar', () {
    // Preparar
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
    ciclo.iniciar(tareaId: 'tarea-1', ahora: inicio);
    ciclo.pausar(inicio.add(const Duration(minutes: 10)));

    // Ejecutar
    ciclo.cancelar();

    // Verificar
    expect(ciclo.fase, FasePomodoro.trabajo);
    expect(ciclo.segundosRestantes, 25 * 60);
    expect(ciclo.haySesionEnCurso, isFalse);
  });

  test('CP-ES-10 iniciar el descanso, pausarlo y cancelar', () {
    // Preparar
    final ciclo = CicloPomodoro(minutosTrabajo: 25, minutosDescanso: 5);
    ciclo.iniciar(tareaId: 'tarea-1', ahora: inicio);
    ciclo.sincronizar(inicio.add(const Duration(minutes: 25)));
    ciclo.finalizarFase();
    final inicioDescanso = inicio.add(const Duration(minutes: 25));
    ciclo.iniciar(tareaId: null, ahora: inicioDescanso);
    ciclo.pausar(inicioDescanso.add(const Duration(minutes: 2)));

    // Ejecutar
    ciclo.cancelar();

    // Verificar
    expect(ciclo.fase, FasePomodoro.trabajo);
    expect(ciclo.segundosRestantes, 25 * 60);
    expect(ciclo.esDescansoLargo, isFalse);
  });
}
