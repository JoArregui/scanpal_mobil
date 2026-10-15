import 'package:flutter/material.dart';
import '../../domain/entities/opcion_menu.dart';

// Definición de las opciones del menú
final List<OpcionMenu> menuOptions = [
  OpcionMenu(
    titulo: 'Configuración',
    icono: Icons.settings,
    ruta: '/configuracion',
  ),
  OpcionMenu(
    titulo: 'Actualizar Artículos',
    icono: Icons.cloud_download,
    ruta: '/actualizar_articulos',
  ),
  OpcionMenu(
    titulo: 'Leer Códigos',
    icono: Icons.qr_code_scanner,
    ruta: '/lector',
  ),
  OpcionMenu(
    titulo: 'Enviar Lecturas',
    icono: Icons.cloud_upload,
    ruta: '/enviar_lecturas',
  ),
  OpcionMenu(
    titulo: 'Historial de Envíos',
    icono: Icons.history,
    ruta: '/historial_envios',
  ),
  // PRESENTACION: Ventas/Compras y Comprobar ocultos (sin rastro en menú).
  // OpcionMenu(titulo: 'Ventas', icono: Icons.point_of_sale, ruta: '/venta'),
  // OpcionMenu(titulo: 'Compras', icono: Icons.shopping_cart, ruta: '/compra'),
  // OpcionMenu(
  //   titulo: 'Comprobar Venta',
  //   icono: Icons.playlist_add_check,
  //   ruta: '/comprobacion_venta',
  // ),
  // OpcionMenu(
  //   titulo: 'Comprobar Compra',
  //   icono: Icons.fact_check,
  //   ruta: '/comprobacion_compra',
  // ),
];
