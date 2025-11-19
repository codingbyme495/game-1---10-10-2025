# Contraintes Techniques et Justifications

## 1. Vue d'ensemble

Ce document détaille les contraintes techniques du système de traitement d'images, les choix technologiques effectués, et leurs justifications respectives. Il explicite également la répartition entre les langages C, C++ et C#.

## 2. Contraintes matérielles

### 2.1 Configuration minimale

**Contrainte** : L'application doit fonctionner sur des machines aux ressources limitées.

**Spécifications minimales** :
- **Processeur** : 2 cœurs, 2.0 GHz
- **RAM** : 4 GB
- **Espace disque** : 500 MB pour l'application
- **GPU** : Optionnel (CPU uniquement en mode dégradé)
- **Écran** : 1280x720 minimum

**Justification** :
- Accessibilité à un large public
- Utilisable sur des machines de bureau standards
- Pas de barrière matérielle à l'entrée

**Impact sur l'architecture** :
- Optimisation CPU prioritaire
- Gestion mémoire stricte
- GPU optionnel, non obligatoire
- Streaming pour grandes images

### 2.2 Configuration recommandée

**Spécifications recommandées** :
- **Processeur** : 4+ cœurs, 3.0 GHz, support AVX2
- **RAM** : 8+ GB
- **Espace disque** : 2 GB (avec plugins et cache)
- **GPU** : Compatible OpenCL 1.2+ (optionnel)
- **Écran** : 1920x1080 ou supérieur

**Justification** :
- Performance optimale pour images haute résolution
- Multi-threading efficace
- Cache confortable pour l'historique
- Accélération GPU pour opérations intensives

## 3. Contraintes logicielles

### 3.1 Plateformes cibles

**Contrainte** : Support multi-plateforme natif

**Plateformes** :
- **Windows** : 10, 11 (x64)
- **Linux** : Ubuntu 20.04+, Fedora 35+, autres distributions courantes
- **macOS** : 11+ (Big Sur et supérieur), x64 et ARM64 (M1/M2)

**Justification** :
- Couverture des 3 OS desktop majeurs (>95% du marché)
- Support à long terme des versions
- Architecture x64 universelle (+ ARM64 pour macOS moderne)

**Impact sur l'architecture** :
- Abstraction des APIs système
- Build system cross-platform (CMake)
- Tests CI/CD sur toutes plateformes
- Conditionnels de compilation minimaux

### 3.2 Dépendances externes

**Contrainte** : Minimiser les dépendances tout en utilisant des bibliothèques éprouvées

**Bibliothèques C/C++ obligatoires** :
- **libpng** : Format PNG (très répandu, stable)
- **libjpeg-turbo** : JPEG optimisé (fork de libjpeg)
- **STL/C++ Standard Library** : Inclus avec compilateur

**Bibliothèques C/C++ optionnelles** :
- **libtiff** : Support TIFF
- **OpenCL** : Accélération GPU
- **Eigen** : Mathématiques linéaires (alternative : implémentation custom)

**Frameworks C#** :
- **Avalonia** : UI cross-platform moderne
- **.NET 6+** : Runtime cross-platform
- **ASP.NET Core** : API REST

**Justification** :
- Bibliothèques C : matures, performantes, largement testées
- Avalonia : moderne, cross-platform natif, bien maintenu
- .NET 6+ : LTS, performance améliorée, C# moderne

**Licence** : Toutes les bibliothèques choisies ont des licences permissives (MIT, BSD, Apache 2.0)

## 4. Choix des langages : Analyse détaillée

### 4.1 Critères de sélection

Critères évalués pour chaque langage :
1. **Performance** : Temps d'exécution, latence
2. **Contrôle mémoire** : Gestion explicite vs automatique
3. **Productivité** : Vitesse de développement
4. **Interopérabilité** : Capacité à interagir avec autres langages
5. **Écosystème** : Bibliothèques, outils disponibles
6. **Portabilité** : Support multi-plateforme
7. **Sécurité** : Prévention d'erreurs communes

### 4.2 Langage C : Core de performance critique

#### **Utilisation : 25-30% du code**

#### **Modules concernés**
1. **Opérations pixel (pixel_operations.c)**
   - Boucles intensives sur millions de pixels
   - Opérations arithmétiques simples répétées
   
2. **Convolution (convolution.c)**
   - Algorithme central pour filtres
   - Calcul matriciel répétitif
   
3. **SIMD (simd_operations.c)**
   - Intrinsics SSE/AVX pour vectorisation
   - Contrôle fin du code machine généré
   
4. **Gestion mémoire (memory_manager.c)**
   - Allocateur custom, pool de buffers
   - Contrôle total du layout mémoire
   
5. **Conversions colorimétriques (color_space.c)**
   - Transformations mathématiques sur pixels
   - Performance critique

#### **Justifications détaillées**

**Performance maximale**
- Compilation directe sans overhead runtime
- Contrôle précis des optimisations compilateur
- Prédictibilité du code généré
- Benchmarks : C = 100%, C++ = 95-100%, C# = 30-70% (selon opération)

**SIMD explicite**
```c
// Contrôle total des intrinsics
__m256 pixels = _mm256_loadu_ps(data);
__m256 scaled = _mm256_mul_ps(pixels, factor);
_mm256_storeu_ps(result, scaled);
```
- C permet usage direct d'intrinsics sans abstraction
- Optimisation manuelle possible au niveau assembleur
- Dispatch runtime selon CPU (SSE/AVX/AVX2)

**ABI stable pour plugins**
- Interface C = ABI stable et portable
- Pas de name mangling (vs C++)
- Linkage simple depuis C++, C#, Python, etc.
- Standard industriel pour plugins natifs

**Contrôle mémoire**
- Allocation/désallocation explicite
- Pas de garbage collection
- Alignement mémoire contrôlé (pour SIMD)
- Pool de buffers custom possible

**Portabilité**
- Compilateurs C disponibles partout
- Comportement bien défini (ISO C99/C11)
- Moins de complexité que C++ pour cross-compilation

#### **Limitations assumées**

- Pas d'abstraction OO (non nécessaire pour calculs purs)
- Gestion erreurs via codes retour (acceptable pour C core)
- Pas de RAII (compensé par wrappers C++)

### 4.3 Langage C++ : Architecture et logique métier

#### **Utilisation : 50-60% du code**

#### **Modules concernés**

**Engine** (Cœur applicatif)
- `ImageProcessor` : Orchestrateur principal
- `LayerManager` : Gestion des calques
- `HistoryManager` : Undo/Redo
- `SelectionManager` : Sélections
- `PluginManager` : Système de plugins

**Filters** (Filtres)
- Hiérarchie de classes `IFilter`
- Implémentations concrètes (GaussianBlur, Sharpen, etc.)
- Composition de filtres

**Tools** (Outils)
- `ITool` interface
- BrushTool, SelectionTool, etc.
- Gestion d'état complexe

**I/O** (Entrée/Sortie)
- `ImageReader`/`ImageWriter` abstraits
- Implémentations concrètes par format
- ProjectManager

**Infrastructure**
- ThreadPool
- Task scheduling
- Logging

#### **Justifications détaillées**

**Abstraction sans perte de performance**
```cpp
// Zero-cost abstraction
template<typename T>
class Image {
    T* data() { return data_; }  // Inline = aucun overhead
};
```
- Templates résolvus à la compilation
- Inlining agressif par compilateur
- Abstraction = code plus maintenable sans pénalité runtime

**RAII pour sécurité**
```cpp
class Image {
    std::unique_ptr<uint8_t[]> data_;  // Désallocation auto
    ~Image() { /* rien à faire, auto cleanup */ }
};
```
- Ressources gérées automatiquement
- Prévention de fuites mémoire
- Exception-safe (cleanup garanti)

**STL optimisée**
- `std::vector`, `std::map`, etc. très optimisés
- Allocateurs personnalisables
- Algorithmes génériques (`std::transform`, `std::for_each`)

**Smart pointers**
```cpp
std::shared_ptr<Layer> layer;  // Comptage références
std::unique_ptr<Filter> filter;  // Ownership unique
```
- Gestion automatique de la durée de vie
- Prévention de use-after-free
- Intent clair dans le code

**Interopérabilité avec C**
```cpp
extern "C" {
    #include "pixel_operations.h"  // Appel direct code C
}
```
- Appel de fonctions C sans overhead
- Linkage facile
- Meilleur des deux mondes

**Écosystème riche**
- Boost (si nécessaire)
- Google Test pour tests
- Google Benchmark pour benchmarks
- Eigen pour algèbre linéaire

#### **Standards utilisés**

**C++17 minimum**
- `std::filesystem` pour chemins cross-platform
- `std::optional` pour valeurs optionnelles
- `if constexpr` pour métaprogrammation
- Structured bindings

**C++20 (si supporté)**
- Concepts pour constraints templates
- Modules (futur)
- Ranges

#### **Limitations assumées**

- Temps de compilation plus long que C (mitigé par compilation incrémentale)
- Complexité du langage (mitigé par guidelines strictes)

### 4.4 Langage C# : Interface et services

#### **Utilisation : 15-20% du code**

#### **Modules concernés**

**UI (Interface utilisateur)**
- `MainWindow` : Fenêtre principale
- `ViewPort` : Affichage image avec zoom/pan
- `LayerPanel`, `HistoryPanel`, `ToolBar`
- Dialogs (Open, Save, Settings)

**API REST**
- Controllers ASP.NET Core
- Middleware
- Queue de traitement
- Authentification

**Interop**
- Wrappers C# pour API C native
- Marshalling de structures
- Gestion de la durée de vie des handles

**Scripting** (future extension)
- Interface pour automation
- Binding dynamique

#### **Justifications détaillées**

**Productivité UI**
```xml
<!-- XAML déclaratif -->
<Button Click="OnOpenClick">Open Image</Button>
<Image Source="{Binding CurrentImage}" />
```
- Binding de données intégré
- Design pattern MVVM naturel
- Hot reload pour prototypage rapide
- Designer WYSIWYG

**Avalonia cross-platform**
- Rendu natif sur Win/Linux/macOS
- API unifiée (pas de code spécifique plateforme pour UI)
- Moderne et bien maintenu
- Alternative à Qt (qui nécessiterait C++)

**Rapidité de développement**
- Garbage collection = pas de gestion mémoire manuelle (UI)
- LINQ pour requêtes données
- async/await pour asynchrone
- Tooling Visual Studio / Rider excellent

**ASP.NET Core pour API**
- Framework mature pour REST
- Routing automatique
- Middleware pipeline
- OpenAPI/Swagger intégré
- Excellent performance (vs Python Flask, Node Express)

**Interop P/Invoke robuste**
```csharp
[DllImport("imageproc")]
public static extern int imageproc_load_image(
    [MarshalAs(UnmanagedType.LPStr)] string path,
    out IntPtr handle);
```
- Marshalling automatique des types simples
- Contrôle fin si nécessaire
- Gestion d'erreurs via codes retour ou exceptions

**Écosystème .NET**
- NuGet pour packages
- Excellents outils de test (xUnit, NUnit)
- Profilers performants (dotMemory, dotTrace)

#### **Justifications du choix Avalonia vs alternatives**

**Avalonia vs WPF**
- WPF = Windows uniquement
- Avalonia = cross-platform natif
- API similaire (migration facile)

**Avalonia vs Qt (C++)**
- C# plus productif que C++ pour UI
- Pas besoin d'apprendre Qt
- Séparation claire : C++ = logic, C# = UI

**Avalonia vs Electron**
- Performance native vs web
- Taille réduite (pas de Chromium embarqué)
- Accès natif plus simple

#### **Limitations assumées**

- Latence GC (acceptable pour UI, pas pour traitement)
- Dépendance .NET runtime (acceptable, taille ~60MB)
- P/Invoke overhead (mitigé par batching d'appels)

### 4.5 Tableau comparatif

| Critère | C | C++ | C# |
|---------|---|-----|----|
| **Performance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Contrôle mémoire** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Productivité** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Sécurité mémoire** | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Abstraction** | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Interop** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **UI Development** | ⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Build Speed** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

### 4.6 Stratégie d'interopérabilité

#### **C ↔ C++**
```cpp
// C header
#ifdef __cplusplus
extern "C" {
#endif
    void process_pixels(uint8_t* data, size_t size);
#ifdef __cplusplus
}
#endif

// C++ usage
extern "C" {
    #include "pixel_ops.h"
}
// Direct call, zero overhead
process_pixels(img.data(), img.size());
```

#### **C/C++ ↔ C#**
```c
// C export (flat API)
EXPORT int imageproc_apply_filter(
    ImageHandle handle,
    const char* filter_name,
    void* params
);
```

```csharp
// C# import
[DllImport("imageproc")]
private static extern int imageproc_apply_filter(
    IntPtr handle,
    string filterName,
    IntPtr parameters);

// C# wrapper
public void ApplyFilter(string filterName, FilterParameters parameters) {
    IntPtr paramsPtr = Marshal.AllocHGlobal(/* ... */);
    try {
        int result = imageproc_apply_filter(_handle, filterName, paramsPtr);
        if (result != 0) throw new Exception("Filter failed");
    } finally {
        Marshal.FreeHGlobal(paramsPtr);
    }
}
```

## 5. Contraintes de performance

### 5.1 Temps de réponse

**Contrainte** : Application réactive

| Opération | Temps cible | Justification |
|-----------|-------------|---------------|
| Démarrage app | < 3s | UX acceptable |
| Chargement PNG 4K | < 1s | Patience utilisateur limitée |
| Gaussian blur 2K | < 100ms | Feedback temps réel |
| Undo/Redo | < 50ms | Sensation instantanée |
| Changement calque | < 20ms | Fluidité UI |
| Zoom/Pan | 60 FPS | Pas de lag perceptible |

**Moyens techniques** :
- Profiling régulier (perf, VTune)
- Benchmarks automatisés
- Optimisations SIMD
- Multi-threading
- Cache intelligent

### 5.2 Utilisation mémoire

**Contrainte** : Mémoire limitée (4 GB minimum)

**Budget mémoire** :
- Application + libs : ~200 MB
- UI framework : ~100 MB
- Image 4K RGBA : ~64 MB
- Historique (10 étapes) : ~640 MB
- Cache + buffers : ~200 MB
- **Total** : ~1.2 GB (confortable sur 4 GB)

**Stratégies** :
- Streaming pour images > 4K
- Compression de l'historique (deltas)
- Libération agressive de ressources
- Pool de buffers réutilisables

### 5.3 Taille binaire

**Contrainte** : Installeur raisonnable

**Cibles** :
- Exécutables : ~50 MB
- Bibliothèques tierces : ~30 MB
- UI framework (.NET) : ~60 MB
- **Total** : ~150 MB

**Justification** : Acceptable pour une application moderne (vs Photoshop ~3 GB)

## 6. Contraintes de sécurité

### 6.1 Gestion des entrées

**Contrainte** : Prévention des vulnérabilités

**Mesures** :
- Validation stricte des fichiers
- Parsing défensif (limites de taille, format)
- Sanitization des chemins (path traversal)
- Timeouts pour décodage

**Exemples** :
```cpp
// Validation taille
if (width > MAX_IMAGE_WIDTH || height > MAX_IMAGE_HEIGHT) {
    return ERROR_IMAGE_TOO_LARGE;
}

// Validation allocation
size_t required = width * height * 4;
if (required > MAX_ALLOCATION_SIZE) {
    return ERROR_OUT_OF_MEMORY;
}
```

### 6.2 Mémoire

**Contrainte** : Prévention de buffer overflows, use-after-free

**Mesures C** :
- Bounds checking manuel
- Asserts en debug
- AddressSanitizer en développement

**Mesures C++** :
- Smart pointers (unique_ptr, shared_ptr)
- RAII systématique
- `std::vector` au lieu de tableaux bruts

**Mesures C#** :
- Garbage collection (pas de fuites)
- Bounds checking automatique
- Safe handles pour ressources natives

### 6.3 Plugins

**Contrainte** : Isolation des plugins tiers

**Mesures** :
- Chargement dans processus séparé (optionnel)
- Timeout d'exécution
- API restreinte (pas d'accès système complet)
- Exception handling robuste
- Signature de plugins (future extension)

## 7. Contraintes de build et déploiement

### 7.1 Système de build

**Contrainte** : Build reproductible et cross-platform

**Choix : CMake pour C/C++**
- Standard de facto pour C/C++
- Support Windows, Linux, macOS
- Intégration IDE (Visual Studio, CLion, VSCode)
- Package managers (vcpkg, Conan)

**Choix : MSBuild/dotnet pour C#**
- Standard .NET
- Cross-platform via .NET Core/6+
- Intégration Visual Studio, Rider

### 7.2 CI/CD

**Contrainte** : Tests automatiques multi-plateformes

**Pipeline** :
1. Build sur Windows, Linux, macOS
2. Tests unitaires
3. Tests d'intégration
4. Analyse statique (Clang-Tidy)
5. Packaging

**Outils** : GitHub Actions ou GitLab CI

### 7.3 Dépendances

**Contrainte** : Gestion des bibliothèques tierces

**Stratégie** :
- vcpkg pour C/C++ (cross-platform)
- NuGet pour C#
- Submodules Git en dernier recours
- Versions lockées pour reproductibilité

## 8. Contraintes de maintenance

### 8.1 Qualité du code

**Standards** :
- **C** : ISO C11
- **C++** : C++17 minimum (C++20 si disponible)
- **C#** : C# 10+ (.NET 6+)

**Guidelines** :
- C++ Core Guidelines pour C++
- Microsoft C# Coding Conventions
- Clang-format pour formatage automatique

### 8.2 Documentation

**Contraintes** :
- 100% API publique documentée
- Exemples de code
- Architecture documentée (ce document)

**Outils** :
- Doxygen pour C/C++
- XML comments pour C#
- Markdown pour guides

### 8.3 Tests

**Contraintes** :
- Couverture > 80% pour code critique (C/C++)
- Couverture > 60% pour UI (C#)
- Tests de performance (benchmarks)
- Tests multi-plateformes

**Outils** :
- Google Test (C++)
- xUnit (C#)
- Google Benchmark (C++)

## 9. Contraintes légales et licensing

### 9.1 Licences des dépendances

Toutes les bibliothèques utilisées ont des licences permissives :
- **libpng** : libpng license (similaire MIT)
- **libjpeg-turbo** : BSD-like
- **Avalonia** : MIT
- **.NET** : MIT
- **ASP.NET Core** : MIT

**Contrainte** : Pas de GPL pour éviter contamination

### 9.2 License du projet

**Recommandation** : MIT ou Apache 2.0
- Permissives
- Compatibles avec usage commercial
- Reconnues dans l'industrie

## 10. Synthèse des justifications

### 10.1 Pourquoi C pour le core ?
✅ Performance maximale  
✅ Contrôle mémoire total  
✅ SIMD explicite  
✅ ABI stable pour plugins  
✅ Portabilité  

### 10.2 Pourquoi C++ pour l'architecture ?
✅ Abstraction sans perte de performance  
✅ RAII pour sécurité  
✅ Smart pointers  
✅ STL optimisée  
✅ Interop facile avec C  
✅ Écosystème riche  

### 10.3 Pourquoi C# pour UI et API ?
✅ Productivité maximale  
✅ Avalonia cross-platform  
✅ ASP.NET Core pour REST  
✅ Tooling excellent  
✅ Binding de données  
✅ Interop P/Invoke robuste  

### 10.4 Pourquoi cette combinaison ?

**Synergie** : 
- C = performance pure
- C++ = architecture robuste
- C# = développement rapide

**Séparation des responsabilités** :
- Performance critique → C
- Logique métier → C++
- Interface utilisateur → C#

**Interopérabilité** :
- C ↔ C++ : natif, zero-cost
- C/C++ ↔ C# : P/Invoke éprouvé

**Résultat** : Application performante, maintenable, et productive à développer.

## Conclusion

Les choix techniques effectués répondent aux contraintes de :
- ✅ **Performance** : C/C++ pour le cœur, SIMD, multi-threading
- ✅ **Portabilité** : Windows, Linux, macOS supportés
- ✅ **Extensibilité** : Plugins via ABI C stable
- ✅ **Productivité** : C# pour UI et API
- ✅ **Sécurité** : Smart pointers, validation, isolation
- ✅ **Maintenabilité** : Architecture claire, tests, documentation

Cette approche multi-langage exploite les forces de chaque technologie tout en maintenant une architecture cohérente et performante.
