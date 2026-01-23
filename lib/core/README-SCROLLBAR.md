# CustomScrollbar - Composant Scrollbar DSFR

## Vue d'ensemble

Composant de scrollbar personnalisée conforme au système de design de l'État français (DSFR).

### Caractéristiques

✅ **Toujours visible** - La scrollbar reste visible en permanence  
✅ **Style tube arrondi** - Design moderne avec bordures arrondies  
✅ **Couleurs personnalisables** - Adaptables selon le contexte  
✅ **Intégration facile** - Wrapper simple autour de n'importe quel widget scrollable  
✅ **Comportement responsive** - Épaisseur et rayon adaptés à la taille de l'écran  

## Widgets disponibles

### 1. CustomScrollbar (Base)
Widget de base avec toutes les options de personnalisation.

```dart
CustomScrollbar(
  controller: _scrollController,
  thumbColor: Color(0xFF000091),    // Couleur du curseur
  trackColor: Color(0xFFEEEEEE),    // Couleur de la piste
  thickness: 12.0,                   // Épaisseur (optionnel, responsive par défaut)
  radius: 6.0,                       // Rayon des bords (optionnel, responsive par défaut)
  isAlwaysShown: true,              // Toujours visible
  child: ListView(...),
)
```

### 2. DsfrScrollbar (Recommandé)
Scrollbar avec les couleurs DSFR par défaut (Blue France).

```dart
DsfrScrollbar(
  controller: _scrollController,
  child: ListView.builder(
    controller: _scrollController,
    itemCount: items.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(items[index]),
    ),
  ),
)
```

### 3. DsfrScrollbarRed
Scrollbar avec couleur Red Marianne (pour les éléments critiques).

```dart
DsfrScrollbarRed(
  controller: _scrollController,
  child: ListView(...),
)
```

### 4. DsfrScrollbarGray
Scrollbar avec couleur grise subtile.

```dart
DsfrScrollbarGray(
  controller: _scrollController,
  child: ListView(...),
)
```

## Responsive Design

L'épaisseur et le rayon s'adaptent automatiquement selon la taille de l'écran :

| Taille écran | Épaisseur | Rayon |
|-------------|-----------|-------|
| Mobile (<600px) | 8px | 4px |
| Tablet (600-900px) | 10px | 5px |
| Desktop (>900px) | 12px | 6px |

## Exemples d'utilisation

### GridView avec DsfrScrollbar

```dart
Expanded(
  child: DsfrScrollbar(
    controller: _scrollController,
    child: GridView.builder(
      controller: _scrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => Card(...),
    ),
  ),
)
```

### ListView avec scrollbar personnalisée

```dart
DsfrScrollbar(
  controller: _myController,
  child: ListView.separated(
    controller: _myController,
    itemCount: users.length,
    separatorBuilder: (_, __) => Divider(),
    itemBuilder: (context, index) => UserTile(users[index]),
  ),
)
```

### SingleChildScrollView avec scrollbar

```dart
DsfrScrollbar(
  controller: _scrollController,
  child: SingleChildScrollView(
    controller: _scrollController,
    child: Column(
      children: [
        // Votre contenu long ici
      ],
    ),
  ),
)
```

## Intégration dans les pages

### Pages déjà intégrées
- ✅ **InterpretersPage** - GridView et ListView avec DsfrScrollbar
- ✅ **MissionsPage** - ListView avec DsfrScrollbar
- ✅ **AdminPage** - ListView mobile avec DsfrScrollbar

### Comment intégrer dans une nouvelle page

1. **Importer le composant**
```dart
import '../core/custom_scrollbar.dart';
```

2. **Créer un ScrollController**
```dart
class _MyPageState extends State<MyPage> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
```

3. **Envelopper votre widget scrollable**
```dart
DsfrScrollbar(
  controller: _scrollController,
  child: YourScrollableWidget(
    controller: _scrollController,
    // ...
  ),
)
```

## Couleurs DSFR

| Composant | Couleur | Code |
|-----------|---------|------|
| DsfrScrollbar (thumb) | Blue France | #000091 |
| DsfrScrollbarRed (thumb) | Red Marianne | #E1000F |
| DsfrScrollbarGray (thumb) | Gray | #666666 |
| Track (tous) | Light Gray | #EEEEEE |

## Notes techniques

- Le `thumbVisibility` et `trackVisibility` sont configurés à `true` par défaut
- Le `minThumbLength` est fixé à 48px pour une bonne accessibilité
- Les bordures de la piste sont transparentes pour un rendu propre
- Compatible avec tous les widgets scrollables Flutter : ListView, GridView, SingleChildScrollView, CustomScrollView, etc.

## Personnalisation avancée

Pour créer votre propre variante de couleur :

```dart
class MyCustomScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController controller;

  const MyCustomScrollbar({
    Key? key,
    required this.child,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScrollbar(
      controller: controller,
      thumbColor: const Color(0xFFYOURCOLOR),
      trackColor: const Color(0xFFYOURTRACK),
      child: child,
    );
  }
}
```
