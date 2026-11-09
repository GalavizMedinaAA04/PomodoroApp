import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sync_service.dart';

/// Pantalla de cuenta (registro, inicio y cierre de sesión) y respaldo en el
/// servidor mediante `SyncService` (RF-08, RF-09, CU-06).
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, this.syncService});

  final SyncService? syncService;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late final SyncService _service = widget.syncService ?? SyncService();

  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController(text: SyncService.urlPorDefecto);
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();

  bool _modoRegistro = false;
  bool _cargando = false;
  String? _tokenActual;
  String? _correoActual;
  String? _ultimoMensaje;
  bool _ultimoExito = true;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstado() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _urlCtrl.text =
          prefs.getString(SyncService.claveUrlApi) ?? SyncService.urlPorDefecto;
      _tokenActual = prefs.getString(SyncService.claveToken);
      _correoActual = prefs.getString(SyncService.claveCorreo);
    });
  }

  Future<void> _autenticar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _ultimoMensaje = null;
    });

    final resultado = _modoRegistro
        ? await _service.registrar(
            nombre: _nombreCtrl.text,
            correo: _correoCtrl.text,
            clave: _claveCtrl.text,
            baseUrl: _urlCtrl.text,
          )
        : await _service.iniciarSesion(
            correo: _correoCtrl.text,
            clave: _claveCtrl.text,
            baseUrl: _urlCtrl.text,
          );

    await _cargarEstado();
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _ultimoExito = resultado.exito;
      _ultimoMensaje = resultado.mensaje;
      if (resultado.exito) _claveCtrl.clear();
    });
  }

  Future<void> _sincronizarAhora() async {
    setState(() {
      _cargando = true;
      _ultimoMensaje = null;
    });

    final resultado = await _service.sincronizar(baseUrl: _urlCtrl.text);
    await _cargarEstado();
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _ultimoExito = resultado.exito;
      _ultimoMensaje = resultado.mensaje;
    });
  }

  Future<void> _cerrarSesion() async {
    setState(() => _cargando = true);
    final resultado = await _service.cerrarSesion(baseUrl: _urlCtrl.text);
    await _cargarEstado();
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _ultimoExito = resultado.exito;
      _ultimoMensaje = resultado.mensaje;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final autenticado = _tokenActual != null && _tokenActual!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección de la API (HTTPS)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
              ),
              const SizedBox(height: 24),
              if (autenticado) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user, color: scheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sesión activa: ${_correoActual ?? 'Usuario autenticado'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const Key('btn_sincronizar_ahora'),
                          onPressed: _cargando ? null : _sincronizarAhora,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Sincronizar ahora'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('btn_cerrar_sesion'),
                          onPressed: _cargando ? null : _cerrarSesion,
                          icon: const Icon(Icons.logout),
                          label: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Iniciar sesión'),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Crear cuenta'),
                    ),
                  ],
                  selected: {_modoRegistro},
                  onSelectionChanged: (s) =>
                      setState(() => _modoRegistro = s.first),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_modoRegistro) ...[
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _correoCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final texto = v?.trim() ?? '';
                          if (texto.isEmpty || !texto.contains('@')) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _claveCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña (mínimo 8 caracteres)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 8) {
                            return 'Mínimo 8 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _cargando ? null : _autenticar,
                        child: Text(
                          _modoRegistro ? 'Registrarse' : 'Iniciar sesión',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_cargando) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_ultimoMensaje != null) ...[
                const SizedBox(height: 24),
                Card(
                  color: _ultimoExito
                      ? scheme.secondaryContainer
                      : scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _ultimoMensaje!,
                      style: TextStyle(
                        color: _ultimoExito
                            ? scheme.onSecondaryContainer
                            : scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
