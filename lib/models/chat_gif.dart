class ChatGif {
  final String id;
  final String title;
  final String url;
  final String category;
  final List<String> tags;

  const ChatGif({
    required this.id,
    required this.title,
    required this.url,
    required this.category,
    required this.tags,
  });

  /// Catálogo curated de GIFs animados de alta calidad y carga rápida estilo WhatsApp
  static const List<ChatGif> catalog = [
    // --- Categoría: Trabajo & Proyectos ---
    ChatGif(
      id: 'work_typing_fast',
      title: 'Programando a tope',
      url: 'https://media.giphy.com/media/unQ3IJU2RG7DO/giphy.gif',
      category: 'Trabajo',
      tags: ['programando', 'codigo', 'escribiendo', 'trabajando', 'gato', 'laptop'],
    ),
    ChatGif(
      id: 'work_deal_done',
      title: '¡Trato Hecho!',
      url: 'https://media.giphy.com/media/26gsvAm8UPaczzXz2/giphy.gif',
      category: 'Trabajo',
      tags: ['trato', 'acuerdo', 'apreton', 'negocio', 'contratado', 'listo'],
    ),
    ChatGif(
      id: 'work_rocket_launch',
      title: '¡Despegue y entrega!',
      url: 'https://media.giphy.com/media/3o7btQ8jDTPGDpgc6I/giphy.gif',
      category: 'Trabajo',
      tags: ['cohete', 'despegue', 'entrega', 'lanzamiento', 'exito', 'proyecto'],
    ),
    ChatGif(
      id: 'work_its_working',
      title: '¡Está funcionando!',
      url: 'https://media.giphy.com/media/11ISw85OHnNiL5kBGL/giphy.gif',
      category: 'Trabajo',
      tags: ['funciona', 'working', 'codigo', 'programacion', 'victoria', 'bien'],
    ),
    ChatGif(
      id: 'work_coffee_mode',
      title: 'Modo café activado',
      url: 'https://media.giphy.com/media/hPTZgtzfRIB5Nfb5rL/giphy.gif',
      category: 'Trabajo',
      tags: ['cafe', 'concentrado', 'manana', 'trabajando', 'oficina'],
    ),
    ChatGif(
      id: 'work_money_cash',
      title: '¡Pago Aprobado!',
      url: 'https://media.giphy.com/media/67ThD16oUIQHWEPRuA/giphy.gif',
      category: 'Trabajo',
      tags: ['pago', 'dinero', 'cash', 'escrow', 'liberado', 'aprobado'],
    ),

    // --- Categoría: Reacciones ---
    ChatGif(
      id: 'react_thumbs_up',
      title: 'Pulgar arriba / OK',
      url: 'https://media.giphy.com/media/111ebonMs90YLu/giphy.gif',
      category: 'Reacciones',
      tags: ['ok', 'bien', 'like', 'pulgar', 'de acuerdo', 'entendido'],
    ),
    ChatGif(
      id: 'react_mind_blown',
      title: '¡Increíble / Mente volada!',
      url: 'https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif',
      category: 'Reacciones',
      tags: ['mente', 'wow', 'sorpresa', 'increible', 'genio'],
    ),
    ChatGif(
      id: 'react_clapping',
      title: '¡Aplausos!',
      url: 'https://media.giphy.com/media/nbvFVPiEiJH6JOGIok/giphy.gif',
      category: 'Reacciones',
      tags: ['aplausos', 'bravo', 'bien', 'felicidades', 'excelente'],
    ),
    ChatGif(
      id: 'react_laughing',
      title: 'Risas / Jajaja',
      url: 'https://media.giphy.com/media/lszAB3TzFtRaU/giphy.gif',
      category: 'Reacciones',
      tags: ['risa', 'lol', 'jaja', 'gracioso', 'humor'],
    ),
    ChatGif(
      id: 'react_thinking',
      title: 'Pensando...',
      url: 'https://media.giphy.com/media/d3mlE7uhX8KFgEmY/giphy.gif',
      category: 'Reacciones',
      tags: ['pensando', 'idea', 'cerebro', 'estrategia', 'analizando'],
    ),
    ChatGif(
      id: 'react_this_is_fine',
      title: 'Todo bajo control',
      url: 'https://media.giphy.com/media/9M5jK4GXmD5o1irGrF/giphy.gif',
      category: 'Reacciones',
      tags: ['fine', 'control', 'humor', 'perro', 'fuego', 'calma'],
    ),

    // --- Categoría: Celebración ---
    ChatGif(
      id: 'celeb_dance',
      title: '¡Baile de victoria!',
      url: 'https://media.giphy.com/media/blSTtZehjAZ8I/giphy.gif',
      category: 'Celebración',
      tags: ['baile', 'fiesta', 'victoria', 'celebrar', 'feliz'],
    ),
    ChatGif(
      id: 'celeb_success_kid',
      title: '¡Victoria total!',
      url: 'https://media.giphy.com/media/nXxOjZrbnbRxS/giphy.gif',
      category: 'Celebración',
      tags: ['victoria', 'exito', 'bebe', 'ganamos', 'logrado'],
    ),
    ChatGif(
      id: 'celeb_confetti',
      title: '¡Felicitaciones!',
      url: 'https://media.giphy.com/media/g9582DNuQppxC/giphy.gif',
      category: 'Celebración',
      tags: ['brindis', 'copas', 'felicidades', 'salud', 'celebracion'],
    ),
    ChatGif(
      id: 'celeb_champion',
      title: '¡Campeón!',
      url: 'https://media.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif',
      category: 'Celebración',
      tags: ['campeon', 'numero1', 'ganador', 'fiesta'],
    ),
  ];

  /// Catálogo curated de Stickers transparentes animados para fallback instantáneo estilo WhatsApp
  static const List<ChatGif> stickerCatalog = [
    ChatGif(
      id: 'stk_cat_vibes',
      title: 'Gato bailando',
      url: 'https://media.giphy.com/media/ICOgUNjpvO0PC/giphy.gif',
      category: 'Animales',
      tags: ['gato', 'baile', 'musica', 'vibes', 'divertido'],
    ),
    ChatGif(
      id: 'stk_dog_wave',
      title: 'Perrito saludando',
      url: 'https://media.giphy.com/media/dzaUX7CAG0Ihi/giphy.gif',
      category: 'Animales',
      tags: ['perro', 'hola', 'saludo', 'perrito', 'tierno'],
    ),
    ChatGif(
      id: 'stk_party_parrot',
      title: 'Loro Fiestero',
      url: 'https://media.giphy.com/media/l3q2K5jinAlChoCLS/giphy.gif',
      category: 'Memes',
      tags: ['fiesta', 'loro', 'meme', 'baile', 'celebracion'],
    ),
    ChatGif(
      id: 'stk_deal_shake',
      title: 'Trato Cerrado',
      url: 'https://media.giphy.com/media/26AHONQ79FdWZhAI0/giphy.gif',
      category: 'Trabajo',
      tags: ['trato', 'acuerdo', 'apreton', 'negocio', 'ok'],
    ),
    ChatGif(
      id: 'stk_thumbs_up',
      title: 'Pulgar arriba animado',
      url: 'https://media.giphy.com/media/3o7TKMt1VVNkHV2PaE/giphy.gif',
      category: 'Reacciones',
      tags: ['ok', 'pulgar', 'bien', 'aprobado', 'perfecto'],
    ),
    ChatGif(
      id: 'stk_crying_laugh',
      title: 'Risa a carcajadas',
      url: 'https://media.giphy.com/media/3oz8xAFtqoOUUrsh7W/giphy.gif',
      category: 'Reacciones',
      tags: ['risa', 'lol', 'jaja', 'carcajada', 'lagrimas'],
    ),
    ChatGif(
      id: 'stk_heart_love',
      title: 'Corazón latiendo',
      url: 'https://media.giphy.com/media/l0HlTy9x8FZo0XO1i/giphy.gif',
      category: 'Amor',
      tags: ['amor', 'corazon', 'gracias', 'love', 'tierno'],
    ),
    ChatGif(
      id: 'stk_applause',
      title: 'Aplausos animados',
      url: 'https://media.giphy.com/media/xT0xeJpnrWC4XWblEk/giphy.gif',
      category: 'Celebración',
      tags: ['aplausos', 'bravo', 'genial', 'felicidades'],
    ),
    ChatGif(
      id: 'stk_money_rain',
      title: 'Lluvia de dinero',
      url: 'https://media.giphy.com/media/3oKIPnAiaMCws8nOsE/giphy.gif',
      category: 'Trabajo',
      tags: ['dinero', 'pago', 'cash', 'abundancia', 'rico'],
    ),
    ChatGif(
      id: 'stk_mind_pop',
      title: 'Mente asombrada',
      url: 'https://media.giphy.com/media/26ufcVAp3AiJJsrIs/giphy.gif',
      category: 'Reacciones',
      tags: ['wow', 'sorpresa', 'mente', 'asombro'],
    ),
    ChatGif(
      id: 'stk_hi_wave',
      title: 'Hola / Saludos',
      url: 'https://media.giphy.com/media/mlvseq9yvZhba/giphy.gif',
      category: 'Saludos',
      tags: ['hola', 'saludo', 'buenas', 'que tal'],
    ),
    ChatGif(
      id: 'stk_typing_cat',
      title: 'Escribiendo rápido',
      url: 'https://media.giphy.com/media/ule4akeXnY9Mb2kfTM/giphy.gif',
      category: 'Trabajo',
      tags: ['trabajo', 'programando', 'rapido', 'escribiendo'],
    ),
  ];

  static List<String> get categories => ['Todos', 'Trabajo', 'Reacciones', 'Celebración'];

  static List<String> get stickerCategories => [
    'Tendencias',
    'Memes',
    'Reacciones',
    'Animales',
    'Amor',
    'Risas',
    'Saludos',
    'Trabajo',
    'Proyectos',
  ];

  static List<ChatGif> search(String query, {String category = 'Todos'}) {
    final cleanQuery = query.trim().toLowerCase();
    return catalog.where((gif) {
      final matchesCategory = category == 'Todos' || gif.category == category;
      if (!matchesCategory) return false;
      if (cleanQuery.isEmpty) return true;
      final matchesTitle = gif.title.toLowerCase().contains(cleanQuery);
      final matchesTags = gif.tags.any((t) => t.toLowerCase().contains(cleanQuery));
      return matchesTitle || matchesTags;
    }).toList();
  }
}
