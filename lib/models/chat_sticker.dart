import 'package:flutter/material.dart';

class ChatSticker {
  final String id;
  final String name;
  final IconData icon;
  final String category;
  final String description;
  final Color backgroundColor;

  String get emoji {
    switch (id) {
      case 'deal_done':
        return '🤝';
      case 'milestone_ready':
        return '🚀';
      case 'approved':
        return '✅';
      case 'working_on_it':
        return '💻';
      case 'reviewing':
        return '🔍';
      case 'designing':
        return '🎨';
      case 'budget_sent':
        return '📄';
      case 'payment_released':
        return '💰';
      case 'understood':
        return '👍';
      case 'thank_you':
        return '⭐';
      case 'questions':
        return '❓';
      case 'in_call':
        return '📞';
      case 'coffee_break':
        return '☕';
      case 'good_job':
        return '🎉';
      case 'fast_speed':
        return '⚡';
      case 'hands_on':
        return '🛠️';
      default:
        return '🎨';
    }
  }

  const ChatSticker({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    required this.description,
    this.backgroundColor = const Color(0xFFF9EAE1),
  });

  /// Catálogo oficial de stickers para FreelancerHub
  static const List<ChatSticker> catalog = [
    // Categoría: Proyectos & Negociación
    ChatSticker(
      id: 'deal_done',
      name: '¡Trato Hecho!',
      icon: Icons.handshake_outlined,
      category: 'Proyectos',
      description: 'Acuerdo cerrado formalmente',
      backgroundColor: Color(0xFFE8F5E9),
    ),
    ChatSticker(
      id: 'milestone_ready',
      name: '¡Entrega Lista!',
      icon: Icons.rocket_launch_outlined,
      category: 'Proyectos',
      description: 'Hito o entregable subido',
      backgroundColor: Color(0xFFE3F2FD),
    ),
    ChatSticker(
      id: 'approved',
      name: '¡Aprobado!',
      icon: Icons.check_circle_outline,
      category: 'Proyectos',
      description: 'Entregable o avance aceptado',
      backgroundColor: Color(0xFFE8F5E9),
    ),
    ChatSticker(
      id: 'working_on_it',
      name: 'En Desarrollo',
      icon: Icons.laptop_chromebook_outlined,
      category: 'Proyectos',
      description: 'Trabajando en la tarea',
      backgroundColor: Color(0xFFEDE7F6),
    ),
    ChatSticker(
      id: 'reviewing',
      name: 'Revisando Avances',
      icon: Icons.search_outlined,
      category: 'Proyectos',
      description: 'Analizando entregables o código',
      backgroundColor: Color(0xFFFFF8E1),
    ),
    ChatSticker(
      id: 'designing',
      name: 'Diseñando',
      icon: Icons.palette_outlined,
      category: 'Proyectos',
      description: 'Creando mockups o UI/UX',
      backgroundColor: Color(0xFFFCE4EC),
    ),
    ChatSticker(
      id: 'budget_sent',
      name: 'Propuesta Enviada',
      icon: Icons.description_outlined,
      category: 'Proyectos',
      description: 'Presupuesto o propuesta compartida',
      backgroundColor: Color(0xFFE0F2F1),
    ),
    ChatSticker(
      id: 'payment_released',
      name: 'Pago Liberado',
      icon: Icons.payments_outlined,
      category: 'Proyectos',
      description: 'Fondo Escrow aprobado',
      backgroundColor: Color(0xFFE8F5E9),
    ),

    // Categoría: Respuestas Rápidas & Comunicación
    ChatSticker(
      id: 'understood',
      name: '¡Entendido!',
      icon: Icons.thumb_up_alt_outlined,
      category: 'Respuestas',
      description: 'Mensaje comprendido',
      backgroundColor: Color(0xFFE3F2FD),
    ),
    ChatSticker(
      id: 'thank_you',
      name: '¡Muchas Gracias!',
      icon: Icons.star_outline,
      category: 'Respuestas',
      description: 'Agradecimiento sincero',
      backgroundColor: Color(0xFFFFF9C4),
    ),
    ChatSticker(
      id: 'questions',
      name: '¿Dudas o Cambios?',
      icon: Icons.help_outline,
      category: 'Respuestas',
      description: 'Consultando feedback',
      backgroundColor: Color(0xFFFFEBEE),
    ),
    ChatSticker(
      id: 'in_call',
      name: 'En Llamada',
      icon: Icons.phone_in_talk_outlined,
      category: 'Respuestas',
      description: 'Atendiendo reunión o llamada',
      backgroundColor: Color(0xFFEDE7F6),
    ),
    ChatSticker(
      id: 'coffee_break',
      name: 'Hora de Café',
      icon: Icons.coffee_outlined,
      category: 'Respuestas',
      description: 'Pausa breve de recarga',
      backgroundColor: Color(0xFFEFEBE9),
    ),
    ChatSticker(
      id: 'good_job',
      name: '¡Gran Trabajo!',
      icon: Icons.celebration_outlined,
      category: 'Respuestas',
      description: 'Felicitaciones por el resultado',
      backgroundColor: Color(0xFFFFF3E0),
    ),
    ChatSticker(
      id: 'fast_speed',
      name: '¡A Toda Marcha!',
      icon: Icons.bolt_outlined,
      category: 'Respuestas',
      description: 'Avanzando con máxima agilidad',
      backgroundColor: Color(0xFFFFF8E1),
    ),
    ChatSticker(
      id: 'hands_on',
      name: '¡Manos a la Obra!',
      icon: Icons.construction_outlined,
      category: 'Respuestas',
      description: 'Iniciando proyecto con entusiasmo',
      backgroundColor: Color(0xFFFBE9E7),
    ),
  ];

  static List<String> get categories => ['Todos', 'Proyectos', 'Respuestas'];

  static ChatSticker? findById(String id) {
    try {
      return catalog.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
