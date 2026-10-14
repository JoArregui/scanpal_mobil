import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'scanner_overlay_painter.dart';

class CameraViewSection extends StatelessWidget {
  final MobileScannerController cameraController;
  final bool cameraActive;
  final bool isProcessing;
  final bool canRead;
  final Function(BarcodeCapture) onDetect;
  final VoidCallback onToggleCamera;
  final VoidCallback onDisparo;
  final double zoomLevel;
  final ValueChanged<double> onZoomChanged;
  final int conteoEstabilidad;
  final int umbralEstabilidad;

  const CameraViewSection({
    super.key,
    required this.cameraController,
    required this.cameraActive,
    required this.isProcessing,
    required this.canRead,
    required this.onDetect,
    required this.onToggleCamera,
    required this.onDisparo,
    required this.zoomLevel,
    required this.onZoomChanged,
    required this.conteoEstabilidad,
    required this.umbralEstabilidad,
  });

  Rect _calcularScanWindow(Size size) {
    final double cutOutWidth = size.width * 0.7;
    final double cutOutHeight = size.height * 0.6;
    final double left = (size.width - cutOutWidth) / 2;
    final double top = (size.height - cutOutHeight) / 2;
    return Rect.fromLTWH(left, top, cutOutWidth, cutOutHeight);
  }

  // Mapea nivel de zoom (1x–5x) a valor 0.0–1.0 que espera MobileScanner
  double _zoomLabel(int nivel) {
    // 1x→0.0, 2x→0.25, 3x→0.5, 4x→0.75, 5x→1.0
    return (nivel - 1) / 4.0;
  }

  int _nivelActual() {
    // Inverso: de 0.0–1.0 a 1–5
    return (zoomLevel * 4).round() + 1;
  }

  @override
  Widget build(BuildContext context) {
    final int nivelActual = _nivelActual();

    return Container(
      height: MediaQuery.of(context).size.height * 0.25,
      width: double.infinity,
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size containerSize =
              Size(constraints.maxWidth, constraints.maxHeight);
          final Rect scanWindow = _calcularScanWindow(containerSize);

          return Stack(
            children: [
              // ── Cámara con scanWindow acotado ──────────────────────────────
              GestureDetector(
                onTap: onDisparo,
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: canRead ? onDetect : null,
                  fit: BoxFit.cover,
                  scanWindow: scanWindow,
                  overlayBuilder: (context, constraints) => Container(),
                ),
              ),

              // ── Overlay: sombra + borde del recuadro ───────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: ScannerOverlayPainter(
                      borderColor: cameraActive
                          ? (conteoEstabilidad > 0
                              ? Colors.greenAccent
                              : Colors.green)
                          : Colors.white,
                      borderWidth: conteoEstabilidad > 0 ? 2.5 : 2.0,
                      borderRadius: 8,
                      overlayColor: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),

              // ── Instrucción superior ────────────────────────────────────────
              if (cameraActive && !isProcessing)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Text(
                        '📷 Centra el código en el recuadro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Indicador de estabilidad ────────────────────────────────────
              if (cameraActive && !isProcessing && conteoEstabilidad > 0)
                Positioned(
                  bottom: 28,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '█' * conteoEstabilidad +
                            '░' *
                                (umbralEstabilidad - conteoEstabilidad),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Botones de zoom 1x–5x ───────────────────────────────────────
              if (cameraActive && !isProcessing)
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        final int nivel = i + 1;
                        final bool activo = nivelActual == nivel;
                        return GestureDetector(
                          onTap: () => onZoomChanged(_zoomLabel(nivel)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: activo
                                  ? Colors.greenAccent
                                  : Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: activo
                                    ? Colors.greenAccent
                                    : Colors.white30,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${nivel}x',
                              style: TextStyle(
                                color: activo ? Colors.black : Colors.white70,
                                fontSize: 11,
                                fontWeight: activo
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

              // ── Pantalla de pausa ───────────────────────────────────────────
              if (!cameraActive && !isProcessing)
                GestureDetector(
                  onDoubleTap: onToggleCamera,
                  child: Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off,
                              color: Colors.white, size: 30),
                          SizedBox(height: 8),
                          Text(
                            'ESCANEO PAUSADO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Indicador de procesamiento ──────────────────────────────────
              if (isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.green, strokeWidth: 3),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Buscando...',
                          style:
                              TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}