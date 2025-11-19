# Image Processing System - Système de Traitement d'Images

## Vue d'ensemble

Ce projet est une application modulaire de traitement et d'édition d'images professionnelle, conçue avec une architecture CPU-first et une extensibilité GPU. Le système combine les forces de trois langages (C, C++, et C#) pour offrir des performances optimales, une architecture robuste et une interface utilisateur moderne.

## Caractéristiques principales

- **Performance optimale** : Core en C avec optimisations SIMD (SSE/AVX)
- **Architecture modulaire** : Composants découplés en C++
- **Interface moderne** : UI cross-platform en C# avec Avalonia
- **Extensibilité** : Système de plugins avec API stable
- **Multi-plateforme** : Support Windows, Linux et macOS
- **API REST** : Intégration avec applications tierces
- **CLI** : Automatisation et batch processing

## Fonctionnalités

### Traitement d'images
- **Convolutions** : Flou gaussien, netteté, détection de contours
- **Filtres de couleur** : Luminosité, contraste, teinte/saturation, courbes
- **Transformations** : Rotation, redimensionnement, recadrage, perspective
- **Outils de dessin** : Pinceaux, sélections, texte, clonage
- **Analyses** : Histogrammes, métadonnées EXIF, statistiques

### Gestion avancée
- **Calques** : Support complet avec modes de fusion et masques
- **Historique** : Undo/Redo illimité
- **Projets** : Sauvegarde avec calques et historique
- **Batch processing** : Traitement par lots automatisé
- **Plugins** : Extensibilité via plugins tiers

## Documentation

### Documents de spécification
- **[Cahier des charges](image_processing_system.md)** : Spécifications fonctionnelles complètes
- **[Spécification technique](docs/technical_specification.md)** : Choix technologiques et architecture détaillée
- **[Architecture logicielle](docs/software_architecture.md)** : Diagrammes et organisation des modules
- **[Plan d'implémentation](docs/implementation_plan.md)** : Découpage par lots et planification
- **[Contraintes techniques](docs/technical_constraints.md)** : Justifications des choix C/C++/C#
- **[Référentiel technique](docs/technical_reference.md)** : API plugins, REST, CLI et interopérabilité
- **[Guide de l'architecte](docs/architect_guide.md)** : Vue d'ensemble pour architectes et développeurs seniors

## Architecture

### Répartition des langages

```
┌─────────────────────────────────────┐
│    Interface (C# - 15-20%)          │
│  UI Desktop, API REST, Bindings     │
└─────────────────────────────────────┘
                ↕ P/Invoke
┌─────────────────────────────────────┐
│  Application (C++ - 50-60%)         │
│  Architecture, Logique métier       │
└─────────────────────────────────────┘
                ↕
┌─────────────────────────────────────┐
│    Core (C - 25-30%)                │
│  Opérations pixel, SIMD, Mémoire    │
└─────────────────────────────────────┘
```

### Modules principaux

- **Core (C)** : Opérations pixel optimisées, convolution, gestion mémoire
- **Engine (C++)** : ImageProcessor, LayerManager, HistoryManager, PluginManager
- **Filters (C++)** : Filtres de convolution, couleur, transformations
- **Tools (C++)** : Outils de dessin, sélection, texte
- **UI (C#)** : Interface Avalonia cross-platform
- **API (C#)** : API REST ASP.NET Core

## Technologies utilisées

### Langages
- **C** (ISO C11) - Performance critique
- **C++** (C++17/20) - Architecture et logique
- **C#** (.NET 6+) - Interface et services

### Frameworks et bibliothèques
- **Avalonia** - UI cross-platform
- **ASP.NET Core** - API REST
- **libpng** - Format PNG
- **libjpeg-turbo** - Format JPEG optimisé
- **Google Test** - Tests C++
- **xUnit** - Tests C#
- **OpenCL** - Accélération GPU (optionnel)

### Outils de build
- **CMake** - Build C/C++
- **MSBuild/dotnet** - Build C#
- **vcpkg** - Gestion des dépendances C/C++
- **NuGet** - Packages .NET

## Prérequis

### Minimum
- CPU : 2 cœurs, 2.0 GHz
- RAM : 4 GB
- Espace disque : 500 MB

### Recommandé
- CPU : 4+ cœurs, 3.0 GHz avec support AVX2
- RAM : 8+ GB
- GPU : Compatible OpenCL 1.2+ (optionnel)

## Installation

_Les instructions d'installation seront ajoutées lors de l'implémentation._

## Utilisation

### Interface graphique
```bash
# Lancer l'application desktop
./ImageProcessor.UI
```

### Ligne de commande
```bash
# Appliquer un filtre
imageproc filter --input image.png --output result.png --type gaussian-blur --radius 5

# Redimensionner
imageproc resize --input image.jpg --output resized.jpg --width 800 --height 600

# Batch processing
imageproc batch --input "*.jpg" --output processed/ --filter brightness --value 1.2
```

### API REST
```bash
# Upload une image
curl -X POST http://localhost:5000/api/v1/images/upload -F "file=@image.png"

# Appliquer un filtre
curl -X POST http://localhost:5000/api/v1/images/{id}/filters/gaussian-blur \
  -H "Content-Type: application/json" \
  -d '{"parameters": {"radius": 5.0}}'
```

## Développement

### Structure du projet
```
image-processing-system/
├── src/
│   ├── core/          # Code C (opérations pixel)
│   ├── engine/        # Code C++ (architecture)
│   ├── filters/       # Filtres C++
│   ├── tools/         # Outils C++
│   ├── io/            # I/O C++
│   ├── ui/            # Interface C#
│   ├── api/           # API REST C#
│   └── cli/           # CLI C++
├── include/           # Headers publics
├── tests/             # Tests unitaires
├── benchmarks/        # Benchmarks de performance
├── docs/              # Documentation
├── examples/          # Exemples de code
└── plugins/           # Plugins
    └── sdk/           # SDK de développement de plugins
```

### Build

_Instructions de build détaillées seront ajoutées lors de l'implémentation._

### Tests
```bash
# Tests C++
ctest --test-dir build

# Tests C#
dotnet test src/ui/ImageProcessor.UI.sln
```

## Contribution

Les contributions sont les bienvenues ! Voir les documents de spécification pour comprendre l'architecture avant de contribuer.

## Extensibilité

### Développer un plugin

Consultez le [Référentiel technique](docs/technical_reference.md) pour la documentation complète de l'API de plugins.

Exemple minimal :
```c
#include "imageproc_plugin.h"

static PluginInfo info = {
    .name = "My Filter",
    .version = "1.0.0",
    .author = "Your Name",
    .api_version = IMAGEPROC_PLUGIN_API_VERSION
};

static PluginError process_image(ImageData* img, const ParameterSet* params) {
    // Votre traitement ici
    return PLUGIN_SUCCESS;
}

// Exports obligatoires
PLUGIN_EXPORT PluginInterface* get_plugin_interface(void) {
    static PluginInterface interface = {
        .get_info = get_info,
        .process_image = process_image,
        // ...
    };
    return &interface;
}
```

## Roadmap

### Version 1.0 (Initial)
- ✅ Spécifications complètes
- ✅ Architecture documentée
- ✅ Plan d'implémentation
- ⬜ Implémentation du core
- ⬜ Interface de base
- ⬜ Filtres essentiels

### Version 1.1
- ⬜ Système de plugins
- ⬜ API REST
- ⬜ Support GPU (OpenCL)

### Version 2.0
- ⬜ Formats avancés (TIFF, RAW)
- ⬜ Effets ML (upscaling, denoising)
- ⬜ Cloud integration

## Licence

_La licence sera définie ultérieurement. Recommandation : MIT ou Apache 2.0_

## Contact

_Informations de contact à ajouter_

---

**Note** : Ce projet est actuellement en phase de spécification et planification. L'implémentation suivra le [plan détaillé](docs/implementation_plan.md) sur 20-26 semaines.