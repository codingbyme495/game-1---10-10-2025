# Image Processing System - Guide de l'Architecte

## Table des matières

1. [Introduction](#1-introduction)
2. [Architecture d'ensemble](#2-architecture-densemble)
3. [Choix technologiques](#3-choix-technologiques)
4. [Modules et composants](#4-modules-et-composants)
5. [Flux de données](#5-flux-de-données)
6. [Patterns de conception](#6-patterns-de-conception)
7. [Gestion de la performance](#7-gestion-de-la-performance)
8. [Extensibilité](#8-extensibilité)
9. [Sécurité](#9-sécurité)
10. [Déploiement](#10-déploiement)
11. [Maintenance et évolution](#11-maintenance-et-évolution)

---

## 1. Introduction

### 1.1 Objectif du document

Ce guide fournit une vision complète de l'architecture du système de traitement d'images, destiné aux architectes logiciels et développeurs seniors qui rejoignent le projet ou doivent prendre des décisions techniques importantes.

### 1.2 Public cible

- **Architectes logiciels** : Comprendre les décisions d'architecture
- **Tech leads** : Guider l'implémentation des équipes
- **Développeurs seniors** : Contribuer aux composants critiques
- **Reviewers** : Évaluer la cohérence architecturale

### 1.3 Philosophie architecturale

L'architecture suit trois principes fondamentaux :

1. **Performance d'abord** : Optimisations au niveau le plus bas, montant vers l'abstraction
2. **Modularité** : Couplage faible, cohésion forte, interfaces claires
3. **Pragmatisme** : Choix technologiques basés sur les besoins réels, pas la hype

## 2. Architecture d'ensemble

### 2.1 Vue à 10 000 pieds

```
┌─────────────────────────────────────────────────────────┐
│                   USER INTERFACES                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Desktop    │  │   REST API   │  │     CLI      │  │
│  │   (C#)       │  │   (C#)       │  │   (C++)      │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                          ↕ P/Invoke / Native
┌─────────────────────────────────────────────────────────┐
│                  APPLICATION LAYER (C++)                │
│         ImageProcessor Facade, Orchestration            │
└─────────────────────────────────────────────────────────┘
                          ↕
┌─────────────────────────────────────────────────────────┐
│                   DOMAIN LAYER (C++)                    │
│    Layers, History, Selection, Plugins, Projects       │
└─────────────────────────────────────────────────────────┘
                          ↕
┌─────────────────────────────────────────────────────────┐
│               PROCESSING LAYER (C/C++)                  │
│           Filters, Tools, Algorithms, SIMD              │
└─────────────────────────────────────────────────────────┘
                          ↕
┌─────────────────────────────────────────────────────────┐
│             INFRASTRUCTURE LAYER (C/C++)                │
│     I/O, Memory, Threading, GPU, Logging                │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Séparation des responsabilités

| Couche | Responsabilité | Langage principal |
|--------|----------------|-------------------|
| **Présentation** | Interface utilisateur, API REST, CLI | C# / C++ |
| **Application** | Orchestration, workflows, use cases | C++ |
| **Domaine** | Logique métier, entités, règles | C++ |
| **Traitement** | Algorithmes, calculs intensifs | C / C++ |
| **Infrastructure** | I/O, threading, mémoire, GPU | C / C++ |

### 2.3 Flux d'exécution typique

```
User Action (UI)
    ↓
Command Creation (C#)
    ↓
P/Invoke Call (C# → C)
    ↓
ImageProcessor Facade (C++)
    ↓
HistoryManager.push() (C++)
    ↓
Filter/Tool Execution (C++)
    ↓
Core Processing (C - SIMD)
    ↓
Result Propagation
    ↓
UI Update (C#)
```

## 3. Choix technologiques

### 3.1 Matrice de décision

| Critère | C | C++ | C# | Justification |
|---------|---|-----|----|--------------  |
| Opérations pixel | ✅ | ⚪ | ❌ | Performance maximale, SIMD |
| Architecture app | ❌ | ✅ | ⚪ | Abstraction + perf |
| Interface graphique | ❌ | ⚪ | ✅ | Productivité, Avalonia |
| API REST | ❌ | ⚪ | ✅ | ASP.NET Core mature |
| Plugins (API) | ✅ | ⚪ | ❌ | ABI stable |
| Tests unitaires | ⚪ | ✅ | ✅ | Google Test, xUnit |

### 3.2 Répartition du code

**Code C** (25-30%)
- `core/pixel_operations.c` - Opérations pixel SIMD
- `core/convolution.c` - Moteur de convolution
- `core/memory_manager.c` - Gestion mémoire
- `core/color_space.c` - Conversions colorimétriques
- `core/simd_operations.c` - Intrinsics SSE/AVX

**Code C++** (50-60%)
- `engine/*` - Architecture principale
- `filters/*` - Filtres et effets
- `tools/*` - Outils de dessin/sélection
- `io/*` - Lecture/écriture fichiers
- `infrastructure/*` - Threading, logging

**Code C#** (15-20%)
- `ui/*` - Interface Avalonia
- `api/*` - API REST ASP.NET
- `bindings/*` - Wrappers P/Invoke

### 3.3 Bibliothèques tierces

**Critères de sélection** :
- Licence permissive (MIT, BSD, Apache 2.0)
- Maintenance active
- Performance prouvée
- Portabilité multi-plateforme

**Bibliothèques retenues** :

| Bibliothèque | Usage | Justification |
|--------------|-------|---------------|
| libpng | Lecture/écriture PNG | Standard de facto |
| libjpeg-turbo | JPEG optimisé | Meilleure perf que libjpeg |
| Avalonia | UI cross-platform | Moderne, .NET natif |
| Google Test | Tests C++ | Mature, riche en features |
| OpenCL | GPU (optionnel) | Portabilité GPU |

## 4. Modules et composants

### 4.1 Module Core (C)

**Rôle** : Opérations bas niveau haute performance

**Composants clés** :
- `pixel_operations` : Manipulation pixel par pixel
- `convolution` : Noyaux de convolution optimisés
- `memory_manager` : Pool de buffers
- `simd_operations` : Vectorisation SSE/AVX

**Principes de design** :
- Fonctions pures (pas d'état global sauf config)
- Pointeurs non-null garantis (assert en debug)
- Tailles validées en entrée
- API documentée avec exemples

**Exemple d'interface** :
```c
// pixel_operations.h
void adjust_brightness_simd(
    uint8_t* pixels,      // [in/out] Données pixel (aligné 16)
    size_t pixel_count,   // Nombre de pixels
    float factor          // Facteur multiplicatif
);
```

### 4.2 Module Engine (C++)

**Rôle** : Orchestration et logique métier

**Composants clés** :

#### ImageProcessor (Facade)
```cpp
class ImageProcessor {
public:
    // Chargement/sauvegarde
    std::unique_ptr<Image> loadImage(const std::string& path);
    void saveImage(const Image& img, const std::string& path);
    
    // Application de filtres
    void applyFilter(Image& img, IFilter& filter);
    
    // Gestion des calques
    LayerManager& layerManager() { return *layer_mgr_; }
    
    // Historique
    void undo();
    void redo();
    
private:
    std::unique_ptr<LayerManager> layer_mgr_;
    std::unique_ptr<HistoryManager> history_mgr_;
    std::unique_ptr<SelectionManager> selection_mgr_;
    std::unique_ptr<PluginManager> plugin_mgr_;
};
```

**Design rationale** :
- Facade pour simplifier l'API publique
- Ownership via unique_ptr (RAII)
- Références pour accès aux managers
- Exception-safe (strong guarantee quand possible)

#### LayerManager
```cpp
class LayerManager {
public:
    LayerId addLayer(std::unique_ptr<Layer> layer);
    void removeLayer(LayerId id);
    void moveLayer(LayerId id, int new_position);
    Layer* getLayer(LayerId id);
    
    // Rendu
    std::unique_ptr<Image> render() const;
    
private:
    std::vector<std::unique_ptr<Layer>> layers_;
    LayerId active_layer_;
};
```

**Invariants** :
- Au moins un calque existe toujours
- LayerId sont uniques et stables
- Ordre des calques préservé

#### HistoryManager
```cpp
class HistoryManager {
public:
    void pushCommand(std::unique_ptr<ICommand> cmd);
    bool canUndo() const;
    bool canRedo() const;
    void undo();
    void redo();
    
private:
    std::vector<std::unique_ptr<ICommand>> undo_stack_;
    std::vector<std::unique_ptr<ICommand>> redo_stack_;
    size_t max_history_size_;
};
```

**Stratégies d'optimisation** :
- Commandes légères (deltas vs snapshots complets)
- Limite configurable (défaut : 50 commandes)
- Compression des données (zlib pour grandes images)

### 4.3 Module Filters (C++)

**Hiérarchie** :
```cpp
class IFilter {
public:
    virtual ~IFilter() = default;
    virtual void apply(Image& img) = 0;
    virtual std::string getName() const = 0;
};

class ConvolutionFilter : public IFilter {
protected:
    Matrix kernel_;
    void applyKernel(Image& img);
};

class GaussianBlur : public ConvolutionFilter {
public:
    GaussianBlur(float radius);
    void apply(Image& img) override;
};
```

**Design pattern** : Template Method
- `IFilter::apply()` = point d'entrée
- Sous-classes implémentent algorithme spécifique
- Comportements communs dans classes de base

### 4.4 Module UI (C#)

**Architecture MVVM** :
```
View (XAML)
    ↕ Binding
ViewModel (C#)
    ↕ P/Invoke
Model (C++ via C API)
```

**Composants** :
- `MainWindow` : Fenêtre principale
- `ViewPort` : Affichage image + zoom/pan
- `LayerPanel` : Liste des calques
- `ToolBar` : Sélection d'outils
- `PropertiesPanel` : Propriétés de l'outil actif

**Synchronisation UI** :
```csharp
// Wrapper C# thread-safe
public class ImageProcessorWrapper {
    private readonly SynchronizationContext _uiContext;
    
    public async Task ApplyFilterAsync(string filterName) {
        // Travail sur thread pool
        await Task.Run(() => {
            NativeAPI.ApplyFilter(_handle, filterName);
        });
        
        // Retour sur UI thread
        await _uiContext.Post(() => {
            OnImageChanged?.Invoke();
        });
    }
}
```

## 5. Flux de données

### 5.1 Chargement d'image

```
User: "Open image.png"
    ↓
UI: FileDialog
    ↓
ViewModel: LoadImageCommand
    ↓
[P/Invoke] imageproc_load_image(path)
    ↓
ImageIO: Detect format (PNG)
    ↓
PNGReader: libpng decode
    ↓
Image object created
    ↓
LayerManager: addLayer(image)
    ↓
[Return] ImageHandle
    ↓
ViewModel: Update bindings
    ↓
View: Display image
```

### 5.2 Application de filtre

```
User: "Apply Gaussian Blur"
    ↓
UI: Slider (radius = 5)
    ↓
ViewModel: ApplyFilterCommand
    ↓
HistoryManager: push(FilterCommand)
    ↓
FilterCommand: execute()
    ↓
GaussianBlur: apply(image)
    ↓
ConvolutionFilter: applyKernel()
    ↓
[C] convolve_separable_simd()
    ↓
ThreadPool: Parallelize by rows
    ↓
SIMD: Process 16 pixels/iteration
    ↓
Result written to image
    ↓
UI: Refresh display
```

### 5.3 Undo/Redo

```
User: Ctrl+Z (Undo)
    ↓
HistoryManager: undo()
    ↓
Pop command from undo_stack
    ↓
Command: undo()
    ↓
Restore previous state (delta)
    ↓
Push to redo_stack
    ↓
UI: Refresh
```

## 6. Patterns de conception

### 6.1 Patterns structurels utilisés

#### Facade
**Où** : `ImageProcessor`  
**Pourquoi** : Simplifier l'API pour clients (UI, CLI, API)  
**Bénéfice** : Un point d'entrée, complexité cachée

#### Adapter
**Où** : `ImageReader` implémentations  
**Pourquoi** : Unifier libpng, libjpeg, etc.  
**Bénéfice** : Code client indépendant du format

#### Composite
**Où** : Hiérarchie de calques  
**Pourquoi** : Groupes de calques traités uniformément  
**Bénéfice** : Opérations récursives naturelles

#### Proxy
**Où** : Tuiles d'images  
**Pourquoi** : Chargement paresseux pour grandes images  
**Bénéfice** : Économie mémoire

### 6.2 Patterns comportementaux utilisés

#### Command
**Où** : Toutes opérations modifiant l'image  
**Pourquoi** : Undo/Redo, macros, batch  
**Bénéfice** : Historique transparent

**Exemple** :
```cpp
class FilterCommand : public ICommand {
    Image snapshot_before_;
    std::unique_ptr<IFilter> filter_;
    
public:
    void execute() override {
        snapshot_before_ = image_.clone();
        filter_->apply(image_);
    }
    
    void undo() override {
        image_ = snapshot_before_;
    }
};
```

#### Strategy
**Où** : Interpolation (resize), modes de fusion  
**Pourquoi** : Algorithmes interchangeables  
**Bénéfice** : Extensibilité facile

#### Observer
**Où** : Événements d'image (modification, chargement)  
**Pourquoi** : Découplage UI/logique  
**Bénéfice** : UI réactive

### 6.3 Patterns créationnels utilisés

#### Factory
**Où** : Création de filtres, readers, tools  
**Pourquoi** : Création polymorphique  
**Bénéfice** : Extensibilité via enregistrement

**Exemple** :
```cpp
class FilterFactory {
    std::map<std::string, FilterCreator> registry_;
    
public:
    template<typename T>
    void registerFilter(const std::string& name) {
        registry_[name] = []() { return std::make_unique<T>(); };
    }
    
    std::unique_ptr<IFilter> create(const std::string& name) {
        return registry_[name]();
    }
};
```

#### Singleton
**Où** : `PluginManager`, `ConfigManager` (avec prudence)  
**Pourquoi** : Instance unique globale  
**Bénéfice** : Point d'accès global  
**Caveat** : Testabilité réduite, hidden dependencies

#### Object Pool
**Où** : Buffers mémoire, threads  
**Pourquoi** : Réutilisation, réduction allocations  
**Bénéfice** : Performance (pas de malloc/free répétés)

## 7. Gestion de la performance

### 7.1 Stratégies d'optimisation

#### Niveau 1 : Algorithmes
- Choisir algorithmes à complexité optimale (O(n) vs O(n²))
- Exploiter propriétés mathématiques (séparabilité convolutions)
- Éviter calculs redondants (memoization)

#### Niveau 2 : Données
- Layout mémoire cache-friendly (SoA vs AoS)
- Alignement pour SIMD (16/32 bytes)
- Préfetching des données

#### Niveau 3 : Code
- SIMD pour parallélisme data-level
- Multi-threading pour parallélisme task-level
- Inline functions critiques
- Branch prediction hints

### 7.2 Optimisations SIMD

**Exemple : Brightness adjustment**

Version scalaire :
```c
void adjust_brightness_scalar(uint8_t* pixels, size_t count, float factor) {
    for (size_t i = 0; i < count; i++) {
        int value = (int)(pixels[i] * factor);
        pixels[i] = value > 255 ? 255 : value;
    }
}
// Performance : 100ms pour 8MP image
```

Version SSE :
```c
void adjust_brightness_sse(uint8_t* pixels, size_t count, float factor) {
    __m128 factor_vec = _mm_set1_ps(factor);
    
    for (size_t i = 0; i < count; i += 16) {
        // Charger 16 bytes
        __m128i pixels_i = _mm_loadu_si128((__m128i*)&pixels[i]);
        
        // Convertir en float (4 à la fois)
        __m128 pixels_f = _mm_cvtepi32_ps(_mm_cvtepu8_epi32(pixels_i));
        
        // Multiplier
        pixels_f = _mm_mul_ps(pixels_f, factor_vec);
        
        // Clamper et reconvertir
        // ... (détails omis pour brièveté)
    }
}
// Performance : 25ms pour 8MP image (4x speedup)
```

### 7.3 Parallélisation

**Stratégie de partitionnement** :

```cpp
void parallel_process_image(Image& img, 
    std::function<void(int row_start, int row_end)> process_fn) {
    
    int num_threads = std::thread::hardware_concurrency();
    int rows_per_thread = img.height() / num_threads;
    
    std::vector<std::future<void>> futures;
    
    for (int t = 0; t < num_threads; t++) {
        int start = t * rows_per_thread;
        int end = (t == num_threads - 1) ? img.height() : start + rows_per_thread;
        
        futures.push_back(std::async(std::launch::async, process_fn, start, end));
    }
    
    // Attendre complétion
    for (auto& f : futures) {
        f.get();
    }
}
```

**Benchmarks cibles** :

| Opération | Image 2K | Image 4K | Hardware |
|-----------|----------|----------|----------|
| Gaussian Blur | < 50ms | < 100ms | 4-core CPU |
| Edge Detection | < 30ms | < 70ms | 4-core CPU |
| Brightness | < 10ms | < 25ms | 4-core CPU |
| Resize (bicubic) | < 100ms | < 250ms | 4-core CPU |

### 7.4 Gestion mémoire

**Pool de buffers** :

```c
typedef struct {
    void* buffers[MAX_BUFFERS];
    bool in_use[MAX_BUFFERS];
    size_t buffer_size;
    int count;
} BufferPool;

void* acquire_buffer(BufferPool* pool) {
    for (int i = 0; i < pool->count; i++) {
        if (!pool->in_use[i]) {
            pool->in_use[i] = true;
            return pool->buffers[i];
        }
    }
    return NULL; // Pool exhausted
}
```

**Avantages** :
- Pas d'allocations répétées
- Cache de CPU préservé
- Temps déterministe

## 8. Extensibilité

### 8.1 Points d'extension

| Point d'extension | Mécanisme | Exemples |
|-------------------|-----------|----------|
| Nouveaux filtres | `IFilter` interface | Custom blur, artistic effects |
| Nouveaux outils | `ITool` interface | Custom brush, stamps |
| Formats de fichiers | `IImageReader/Writer` | TIFF, WebP, RAW |
| Backends GPU | `ComputeBackend` | Vulkan, Metal |
| Plugins tiers | Plugin API (C) | Vendor-specific effects |

### 8.2 Versioning et compatibilité

**API Plugin** :
- Version majeure : Breaking changes
- Version mineure : Nouveaux features (rétrocompatibles)
- Version patch : Bug fixes

**Gestion de la compatibilité** :
```c
#define PLUGIN_API_VERSION_MAJOR 1
#define PLUGIN_API_VERSION_MINOR 0
#define PLUGIN_API_VERSION_PATCH 0

bool is_compatible(int plugin_major, int plugin_minor) {
    if (plugin_major != PLUGIN_API_VERSION_MAJOR) {
        return false; // Incompatible
    }
    if (plugin_minor > PLUGIN_API_VERSION_MINOR) {
        return false; // Plugin trop récent
    }
    return true; // Compatible
}
```

## 9. Sécurité

### 9.1 Validation des entrées

**Principe** : Ne jamais faire confiance aux données externes

```cpp
bool ImageReader::validateHeader(const FileHeader& header) {
    // Limites raisonnables
    const uint32_t MAX_DIMENSION = 65536; // 64K
    const uint64_t MAX_SIZE = 4ULL * 1024 * 1024 * 1024; // 4 GB
    
    if (header.width == 0 || header.width > MAX_DIMENSION) {
        return false;
    }
    
    if (header.height == 0 || header.height > MAX_DIMENSION) {
        return false;
    }
    
    uint64_t required_size = (uint64_t)header.width * header.height * 4;
    if (required_size > MAX_SIZE) {
        return false;
    }
    
    return true;
}
```

### 9.2 Prévention des vulnérabilités

**Buffer Overflows** :
- Utiliser `std::vector` au lieu de tableaux bruts
- Bounds checking systématique
- AddressSanitizer en développement

**Use-After-Free** :
- Smart pointers (unique_ptr, shared_ptr)
- RAII systématique
- Ownership clair

**Integer Overflow** :
```cpp
bool safe_multiply(uint32_t a, uint32_t b, uint64_t* result) {
    uint64_t r = (uint64_t)a * b;
    if (r > UINT32_MAX) {
        return false; // Overflow
    }
    *result = r;
    return true;
}
```

### 9.3 Isolation des plugins

```cpp
class PluginSandbox {
    std::chrono::seconds timeout_;
    
public:
    PluginError executeWithTimeout(Plugin& plugin, ImageData* img) {
        auto future = std::async(std::launch::async, [&]() {
            return plugin.process(img);
        });
        
        if (future.wait_for(timeout_) == std::future_status::timeout) {
            // Tuer le plugin (process séparé si implémenté)
            return PLUGIN_ERROR_TIMEOUT;
        }
        
        return future.get();
    }
};
```

## 10. Déploiement

### 10.1 Structure de déploiement

```
ImageProcessor/
├── bin/
│   ├── imageproc.exe           # CLI
│   ├── ImageProcessor.UI.exe   # Desktop app
│   ├── imageproc_core.dll      # Core C/C++
│   └── imageproc_engine.dll    # Engine C++
├── lib/
│   ├── libpng16.dll
│   ├── jpeg62.dll
│   └── ... (dépendances)
├── plugins/
│   └── (plugins utilisateur)
├── resources/
│   ├── icons/
│   ├── translations/
│   └── presets/
└── docs/
    └── manual.pdf
```

### 10.2 CI/CD Pipeline

```yaml
# .github/workflows/build.yml
name: Build and Test

on: [push, pull_request]

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build C/C++
        run: |
          cmake -B build -G "Visual Studio 17 2022"
          cmake --build build --config Release
      - name: Build C#
        run: dotnet build src/ui/ImageProcessor.UI.sln
      - name: Run tests
        run: |
          ctest --test-dir build -C Release
          dotnet test src/ui/ImageProcessor.UI.sln
  
  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: sudo apt-get install libpng-dev libjpeg-dev
      - name: Build
        run: |
          cmake -B build -DCMAKE_BUILD_TYPE=Release
          cmake --build build
      - name: Test
        run: ctest --test-dir build
```

### 10.3 Packaging

**Windows** : NSIS ou WiX pour MSI
**Linux** : AppImage + .deb + .rpm
**macOS** : Bundle .app + DMG

## 11. Maintenance et évolution

### 11.1 Métriques de qualité

| Métrique | Cible | Outil |
|----------|-------|-------|
| Couverture tests (C++) | > 80% | gcov, lcov |
| Couverture tests (C#) | > 60% | dotCover |
| Complexité cyclomatique | < 15 | Lizard |
| Duplications | < 5% | CPD |
| Warnings | 0 | Clang, MSVC /W4 |

### 11.2 Roadmap technique

**Version 1.0** (Initial release)
- Core fonctionnel
- Filtres de base
- UI desktop
- CLI

**Version 1.1** (Q+3 mois)
- Plugins tiers
- API REST
- Support GPU (OpenCL)

**Version 2.0** (Q+6 mois)
- Formats avancés (TIFF multi-page, RAW)
- Effets ML (upscaling, denoising)
- Cloud integration

### 11.3 Dette technique

**Zones identifiées** :
1. Gestion mémoire C (à migrer vers C++ progressivement)
2. Tests UI (augmenter couverture)
3. Documentation API (exemples manquants)

**Plan de remboursement** :
- 20% du temps sprint dédié à la dette
- Refactoring incrémental
- Pas de grand rewrite

## Conclusion

Cette architecture combine:
- **Performance** : C/SIMD pour opérations critiques
- **Maintenabilité** : C++ avec patterns éprouvés
- **Productivité** : C# pour UI et API

Le résultat est un système modulaire, performant, extensible et maintenable qui répond aux exigences d'un logiciel de traitement d'images professionnel.

---

**Document version** : 1.0  
**Dernière mise à jour** : 2025-11-18  
**Auteur** : Architecture Team  
**Reviewers** : Tech Leads, Senior Engineers
