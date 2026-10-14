import 'package:flutter/material.dart';
import '../../domain/entities/opcion_menu.dart';

class HomeMenuItem extends StatelessWidget {
  final OpcionMenu opcion;

  const HomeMenuItem({super.key, required this.opcion});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          
          debugPrint('Navegando a: ${opcion.ruta}'); 
          
          if (opcion.ruta.isNotEmpty) {
            Navigator.of(context).pushNamed(opcion.ruta);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
            
              Flexible(
                child: Icon(
                  opcion.icono,
                  size: 48.0,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                opcion.titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}