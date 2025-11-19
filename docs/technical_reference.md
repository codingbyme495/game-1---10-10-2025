# Référentiel Technique - Plugins, API et Compatibilité Multilangage

## 1. Vue d'ensemble

Ce document constitue le référentiel technique pour :
1. Le système de plugins extensible
2. L'API REST pour intégration externe
3. L'interface en ligne de commande (CLI)
4. La compatibilité et l'interopérabilité des langages

## 2. Système de Plugins

### 2.1 Architecture du système de plugins

#### **2.1.1 Principes de conception**

- **Isolation** : Plugins exécutés de manière isolée pour éviter crashes
- **ABI stable** : Interface en C pur pour compatibilité binaire
- **Versioning** : Compatibilité vérifiée au chargement
- **Sandboxing** : Accès restreint aux ressources système
- **Hot-reload** : Possibilité de recharger plugins sans redémarrer

#### **2.1.2 Architecture**

```
Application Core
      ↓
┌─────────────────┐
│ PluginManager   │ ← Gestion du cycle de vie
└────────┬────────┘
         ↓ Scans
┌─────────────────┐
│ Plugin Directory│ ← /plugins/*.dll|.so|.dylib
└────────┬────────┘
         ↓ Loads
┌─────────────────┐
│   Plugin DLL    │ ← Bibliothèque dynamique
│  (C Interface)  │
└────────┬────────┘
         ↓ Calls
┌─────────────────┐
│ Plugin Code     │ ← Implémentation (C, C++, Rust, etc.)
└─────────────────┘
```

### 2.2 API de Plugin (C)

#### **2.2.1 Structures de données**

```c
#ifndef IMAGEPROC_PLUGIN_H
#define IMAGEPROC_PLUGIN_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Version de l'API
#define IMAGEPROC_PLUGIN_API_VERSION 1

// Informations du plugin
typedef struct {
    const char* name;           // Nom du plugin
    const char* version;        // Version (semver)
    const char* author;         // Auteur
    const char* description;    // Description
    int api_version;            // Version API supportée
} PluginInfo;

// Formats de pixels supportés
typedef enum {
    PIXEL_FORMAT_RGB,
    PIXEL_FORMAT_RGBA,
    PIXEL_FORMAT_GRAYSCALE,
    PIXEL_FORMAT_GRAYSCALE_ALPHA
} PixelFormat;

// Données d'image passées au plugin
typedef struct {
    uint8_t* data;              // Pointeur vers données pixel
    uint32_t width;             // Largeur
    uint32_t height;            // Hauteur
    PixelFormat format;         // Format des pixels
    uint32_t stride;            // Octets par ligne
    void* user_data;            // Données custom
} ImageData;

// Paramètres génériques
typedef struct {
    const char* key;
    union {
        int int_value;
        float float_value;
        const char* string_value;
    } value;
    enum {
        PARAM_TYPE_INT,
        PARAM_TYPE_FLOAT,
        PARAM_TYPE_STRING
    } type;
} Parameter;

typedef struct {
    Parameter* params;
    size_t count;
} ParameterSet;

// Codes d'erreur
typedef enum {
    PLUGIN_SUCCESS = 0,
    PLUGIN_ERROR_INVALID_PARAM = -1,
    PLUGIN_ERROR_OUT_OF_MEMORY = -2,
    PLUGIN_ERROR_UNSUPPORTED_FORMAT = -3,
    PLUGIN_ERROR_INTERNAL = -4
} PluginError;

// Interface du plugin
typedef struct {
    // Obtenir les informations du plugin
    PluginInfo* (*get_info)(void);
    
    // Initialiser le plugin
    int (*initialize)(void);
    
    // Arrêter le plugin
    void (*shutdown)(void);
    
    // Traiter une image
    PluginError (*process_image)(ImageData* image, const ParameterSet* params);
    
    // Obtenir les paramètres supportés (optionnel)
    ParameterSet* (*get_supported_parameters)(void);
    
    // Libérer un ensemble de paramètres
    void (*free_parameters)(ParameterSet* params);
    
} PluginInterface;

// Fonction d'export obligatoire
#ifdef _WIN32
    #define PLUGIN_EXPORT __declspec(dllexport)
#else
    #define PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

// Point d'entrée du plugin
PLUGIN_EXPORT PluginInterface* get_plugin_interface(void);

#ifdef __cplusplus
}
#endif

#endif // IMAGEPROC_PLUGIN_H
```

#### **2.2.2 Implémentation d'un plugin exemple**

```c
#include "imageproc_plugin.h"
#include <stdlib.h>
#include <string.h>

// Informations du plugin
static PluginInfo plugin_info = {
    .name = "Example Brightness Filter",
    .version = "1.0.0",
    .author = "Example Author",
    .description = "Adjusts image brightness",
    .api_version = IMAGEPROC_PLUGIN_API_VERSION
};

// Fonction get_info
static PluginInfo* get_info(void) {
    return &plugin_info;
}

// Initialisation
static int initialize(void) {
    // Initialisation des ressources si nécessaire
    return PLUGIN_SUCCESS;
}

// Arrêt
static void shutdown(void) {
    // Nettoyage des ressources
}

// Traitement principal
static PluginError process_image(ImageData* image, const ParameterSet* params) {
    if (!image || !image->data) {
        return PLUGIN_ERROR_INVALID_PARAM;
    }
    
    // Récupérer le paramètre de luminosité
    float brightness = 1.0f;
    for (size_t i = 0; i < params->count; i++) {
        if (strcmp(params->params[i].key, "brightness") == 0) {
            brightness = params->params[i].value.float_value;
        }
    }
    
    // Traiter l'image
    size_t pixel_count = image->width * image->height;
    size_t channels = (image->format == PIXEL_FORMAT_RGBA) ? 4 : 3;
    
    for (size_t i = 0; i < pixel_count * channels; i++) {
        if (image->format == PIXEL_FORMAT_RGBA && (i % 4 == 3)) {
            continue; // Skip alpha
        }
        
        int value = (int)(image->data[i] * brightness);
        image->data[i] = (uint8_t)(value > 255 ? 255 : value);
    }
    
    return PLUGIN_SUCCESS;
}

// Paramètres supportés
static ParameterSet* get_supported_parameters(void) {
    ParameterSet* params = malloc(sizeof(ParameterSet));
    params->count = 1;
    params->params = malloc(sizeof(Parameter));
    
    params->params[0].key = "brightness";
    params->params[0].type = PARAM_TYPE_FLOAT;
    params->params[0].value.float_value = 1.0f; // Valeur par défaut
    
    return params;
}

static void free_parameters(ParameterSet* params) {
    if (params) {
        free(params->params);
        free(params);
    }
}

// Interface du plugin
static PluginInterface plugin_interface = {
    .get_info = get_info,
    .initialize = initialize,
    .shutdown = shutdown,
    .process_image = process_image,
    .get_supported_parameters = get_supported_parameters,
    .free_parameters = free_parameters
};

// Point d'entrée
PLUGIN_EXPORT PluginInterface* get_plugin_interface(void) {
    return &plugin_interface;
}
```

### 2.3 Gestion des plugins (C++)

#### **2.3.1 PluginManager**

```cpp
#include <string>
#include <map>
#include <memory>
#include <filesystem>

class Plugin {
public:
    Plugin(const std::filesystem::path& path);
    ~Plugin();
    
    bool load();
    void unload();
    bool isLoaded() const { return loaded_; }
    
    const PluginInfo* getInfo() const;
    PluginError processImage(ImageData* image, const ParameterSet* params);
    
private:
    std::filesystem::path path_;
    void* handle_;  // HMODULE (Windows) or void* (Linux/macOS)
    PluginInterface* interface_;
    bool loaded_;
};

class PluginManager {
public:
    static PluginManager& getInstance();
    
    // Charger un plugin depuis un fichier
    bool loadPlugin(const std::filesystem::path& path);
    
    // Décharger un plugin
    void unloadPlugin(const std::string& name);
    
    // Scanner un répertoire pour des plugins
    size_t scanDirectory(const std::filesystem::path& directory);
    
    // Obtenir un plugin par nom
    Plugin* getPlugin(const std::string& name);
    
    // Lister tous les plugins
    std::vector<std::string> listPlugins() const;
    
    // Appliquer un plugin
    bool applyPlugin(const std::string& name, ImageData* image, 
                     const ParameterSet* params);
    
private:
    PluginManager() = default;
    std::map<std::string, std::unique_ptr<Plugin>> plugins_;
};
```

### 2.4 SDK de développement de plugins

#### **2.4.1 Structure du SDK**

```
plugin_sdk/
├── include/
│   └── imageproc_plugin.h        # Header principal
├── examples/
│   ├── brightness_filter/
│   │   ├── brightness.c
│   │   └── CMakeLists.txt
│   ├── blur_filter/
│   │   ├── blur.cpp
│   │   └── CMakeLists.txt
│   └── color_invert/
│       ├── invert.c
│       └── CMakeLists.txt
├── docs/
│   ├── plugin_development_guide.md
│   └── api_reference.md
├── templates/
│   ├── c_plugin_template/
│   └── cpp_plugin_template/
└── CMakeLists.txt
```

#### **2.4.2 CMakeLists.txt pour plugin**

```cmake
cmake_minimum_required(VERSION 3.15)
project(MyPlugin)

# Trouver le SDK
find_path(IMAGEPROC_SDK_INCLUDE imageproc_plugin.h
    HINTS ${IMAGEPROC_SDK_DIR}/include)

include_directories(${IMAGEPROC_SDK_INCLUDE})

# Créer le plugin comme bibliothèque dynamique
add_library(my_plugin SHARED
    my_plugin.c
)

# Pas de préfixe "lib" sur Unix
set_target_properties(my_plugin PROPERTIES PREFIX "")

# Installation
install(TARGETS my_plugin
    LIBRARY DESTINATION plugins
    RUNTIME DESTINATION plugins)
```

### 2.5 Sécurité des plugins

#### **2.5.1 Validation**

```cpp
bool PluginManager::validatePlugin(const PluginInterface* interface) {
    // Vérifier la version de l'API
    const PluginInfo* info = interface->get_info();
    if (info->api_version != IMAGEPROC_PLUGIN_API_VERSION) {
        log_error("Plugin API version mismatch: expected %d, got %d",
                  IMAGEPROC_PLUGIN_API_VERSION, info->api_version);
        return false;
    }
    
    // Vérifier les fonctions obligatoires
    if (!interface->get_info || !interface->initialize || 
        !interface->shutdown || !interface->process_image) {
        log_error("Plugin missing required functions");
        return false;
    }
    
    return true;
}
```

#### **2.5.2 Timeout d'exécution**

```cpp
PluginError PluginManager::applyPluginWithTimeout(
    const std::string& name, ImageData* image, 
    const ParameterSet* params, std::chrono::seconds timeout) {
    
    std::future<PluginError> future = std::async(std::launch::async, [&]() {
        Plugin* plugin = getPlugin(name);
        return plugin->processImage(image, params);
    });
    
    if (future.wait_for(timeout) == std::future_status::timeout) {
        log_error("Plugin '%s' timed out", name.c_str());
        return PLUGIN_ERROR_INTERNAL;
    }
    
    return future.get();
}
```

## 3. API REST

### 3.1 Architecture de l'API

#### **3.1.1 Stack technologique**

- **Framework** : ASP.NET Core 6+
- **Authentication** : API Keys / JWT
- **Documentation** : OpenAPI (Swagger)
- **Validation** : FluentValidation
- **Mapping** : AutoMapper

#### **3.1.2 Endpoints**

**Base URL** : `https://api.example.com/v1`

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/images/upload` | Uploader une image |
| GET | `/images/{id}` | Obtenir métadonnées image |
| GET | `/images/{id}/download` | Télécharger image |
| DELETE | `/images/{id}` | Supprimer image |
| POST | `/images/{id}/filters/{filter}` | Appliquer un filtre |
| POST | `/images/{id}/resize` | Redimensionner |
| POST | `/batch/process` | Traitement par lots |
| GET | `/filters` | Lister filtres disponibles |
| GET | `/tasks/{taskId}` | État d'une tâche |

### 3.2 Implémentation ASP.NET Core

#### **3.2.1 Controller principal**

```csharp
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System.Threading.Tasks;

namespace ImageProcessor.API.Controllers
{
    [ApiController]
    [Route("api/v1/images")]
    [Produces("application/json")]
    public class ImageProcessingController : ControllerBase
    {
        private readonly IImageProcessorService _processorService;
        private readonly IStorageService _storageService;
        private readonly ILogger<ImageProcessingController> _logger;
        
        public ImageProcessingController(
            IImageProcessorService processorService,
            IStorageService storageService,
            ILogger<ImageProcessingController> logger)
        {
            _processorService = processorService;
            _storageService = storageService;
            _logger = logger;
        }
        
        /// <summary>
        /// Upload an image
        /// </summary>
        /// <param name="file">Image file</param>
        /// <returns>Image metadata with ID</returns>
        [HttpPost("upload")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<ActionResult<ImageResponse>> UploadImage(IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest("No file uploaded");
            
            // Valider le type de fichier
            var allowedTypes = new[] { "image/png", "image/jpeg", "image/bmp" };
            if (!allowedTypes.Contains(file.ContentType))
                return BadRequest("Unsupported file type");
            
            // Limiter la taille
            const long maxSize = 50 * 1024 * 1024; // 50 MB
            if (file.Length > maxSize)
                return BadRequest("File too large");
            
            try
            {
                // Sauvegarder et traiter
                var imageId = await _storageService.SaveImageAsync(file);
                var metadata = await _processorService.GetMetadataAsync(imageId);
                
                return Ok(new ImageResponse
                {
                    Id = imageId,
                    Width = metadata.Width,
                    Height = metadata.Height,
                    Format = metadata.Format,
                    UploadedAt = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error uploading image");
                return StatusCode(500, "Internal server error");
            }
        }
        
        /// <summary>
        /// Apply a filter to an image
        /// </summary>
        /// <param name="id">Image ID</param>
        /// <param name="filterName">Filter name</param>
        /// <param name="parameters">Filter parameters</param>
        /// <returns>Task ID for async processing</returns>
        [HttpPost("{id}/filters/{filterName}")]
        [ProducesResponseType(StatusCodes.Status202Accepted)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<TaskResponse>> ApplyFilter(
            string id, 
            string filterName, 
            [FromBody] FilterParameters parameters)
        {
            if (!await _storageService.ImageExistsAsync(id))
                return NotFound("Image not found");
            
            // Créer une tâche asynchrone
            var taskId = await _processorService.EnqueueFilterTaskAsync(
                id, filterName, parameters);
            
            return Accepted(new TaskResponse
            {
                TaskId = taskId,
                Status = "Queued",
                StatusUrl = Url.Action(nameof(GetTaskStatus), new { taskId })
            });
        }
        
        /// <summary>
        /// Get task status
        /// </summary>
        [HttpGet("/api/v1/tasks/{taskId}")]
        public async Task<ActionResult<TaskStatusResponse>> GetTaskStatus(string taskId)
        {
            var status = await _processorService.GetTaskStatusAsync(taskId);
            if (status == null)
                return NotFound("Task not found");
            
            return Ok(status);
        }
        
        /// <summary>
        /// Download processed image
        /// </summary>
        [HttpGet("{id}/download")]
        public async Task<IActionResult> DownloadImage(string id)
        {
            if (!await _storageService.ImageExistsAsync(id))
                return NotFound();
            
            var imageStream = await _storageService.GetImageStreamAsync(id);
            var contentType = await _storageService.GetContentTypeAsync(id);
            
            return File(imageStream, contentType, $"{id}.png");
        }
    }
}
```

#### **3.2.2 Models**

```csharp
public class ImageResponse
{
    public string Id { get; set; }
    public int Width { get; set; }
    public int Height { get; set; }
    public string Format { get; set; }
    public DateTime UploadedAt { get; set; }
}

public class FilterParameters
{
    public Dictionary<string, object> Parameters { get; set; }
}

public class TaskResponse
{
    public string TaskId { get; set; }
    public string Status { get; set; }
    public string StatusUrl { get; set; }
}

public class TaskStatusResponse
{
    public string TaskId { get; set; }
    public string Status { get; set; } // Queued, Processing, Completed, Failed
    public int Progress { get; set; } // 0-100
    public string ResultImageId { get; set; }
    public string ErrorMessage { get; set; }
}
```

#### **3.2.3 Service d'interop avec C++**

```csharp
using System.Runtime.InteropServices;

public class ImageProcessorService : IImageProcessorService
{
    // Import des fonctions natives
    [DllImport("imageproc", CallingConvention = CallingConvention.Cdecl)]
    private static extern int imageproc_load_image(
        [MarshalAs(UnmanagedType.LPStr)] string path,
        out IntPtr handle);
    
    [DllImport("imageproc", CallingConvention = CallingConvention.Cdecl)]
    private static extern int imageproc_apply_filter(
        IntPtr handle,
        [MarshalAs(UnmanagedType.LPStr)] string filterName,
        IntPtr parameters);
    
    [DllImport("imageproc", CallingConvention = CallingConvention.Cdecl)]
    private static extern int imageproc_save_image(
        IntPtr handle,
        [MarshalAs(UnmanagedType.LPStr)] string path);
    
    [DllImport("imageproc", CallingConvention = CallingConvention.Cdecl)]
    private static extern void imageproc_free_image(IntPtr handle);
    
    public async Task<string> ApplyFilterAsync(
        string imageId, string filterName, FilterParameters parameters)
    {
        return await Task.Run(() =>
        {
            IntPtr handle = IntPtr.Zero;
            try
            {
                var imagePath = GetImagePath(imageId);
                int result = imageproc_load_image(imagePath, out handle);
                if (result != 0)
                    throw new Exception("Failed to load image");
                
                // Marshaller les paramètres
                IntPtr paramsPtr = MarshalParameters(parameters);
                
                result = imageproc_apply_filter(handle, filterName, paramsPtr);
                if (result != 0)
                    throw new Exception("Failed to apply filter");
                
                // Sauvegarder le résultat
                var outputId = Guid.NewGuid().ToString();
                var outputPath = GetImagePath(outputId);
                result = imageproc_save_image(handle, outputPath);
                
                Marshal.FreeHGlobal(paramsPtr);
                
                return outputId;
            }
            finally
            {
                if (handle != IntPtr.Zero)
                    imageproc_free_image(handle);
            }
        });
    }
    
    private IntPtr MarshalParameters(FilterParameters parameters)
    {
        // Marshaller les paramètres en structure native
        // ...
        return IntPtr.Zero; // Simplified
    }
}
```

### 3.3 File d'attente de traitement

```csharp
public class ProcessingQueue
{
    private readonly ConcurrentQueue<ProcessingTask> _queue;
    private readonly SemaphoreSlim _semaphore;
    private readonly Dictionary<string, TaskStatus> _taskStatuses;
    
    public ProcessingQueue(int maxConcurrentTasks = 4)
    {
        _queue = new ConcurrentQueue<ProcessingTask>();
        _semaphore = new SemaphoreSlim(maxConcurrentTasks);
        _taskStatuses = new Dictionary<string, TaskStatus>();
        
        // Démarrer les workers
        for (int i = 0; i < maxConcurrentTasks; i++)
        {
            Task.Run(ProcessTasksAsync);
        }
    }
    
    public string EnqueueTask(ProcessingTask task)
    {
        var taskId = Guid.NewGuid().ToString();
        task.Id = taskId;
        _queue.Enqueue(task);
        _taskStatuses[taskId] = new TaskStatus { Status = "Queued" };
        return taskId;
    }
    
    public TaskStatus GetTaskStatus(string taskId)
    {
        return _taskStatuses.GetValueOrDefault(taskId);
    }
    
    private async Task ProcessTasksAsync()
    {
        while (true)
        {
            await _semaphore.WaitAsync();
            
            if (_queue.TryDequeue(out var task))
            {
                try
                {
                    _taskStatuses[task.Id].Status = "Processing";
                    await task.ExecuteAsync();
                    _taskStatuses[task.Id].Status = "Completed";
                }
                catch (Exception ex)
                {
                    _taskStatuses[task.Id].Status = "Failed";
                    _taskStatuses[task.Id].ErrorMessage = ex.Message;
                }
                finally
                {
                    _semaphore.Release();
                }
            }
            else
            {
                _semaphore.Release();
                await Task.Delay(100); // Attendre avant de vérifier à nouveau
            }
        }
    }
}
```

### 3.4 Documentation OpenAPI

```csharp
// Startup.cs ou Program.cs
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Image Processor API",
        Version = "v1",
        Description = "API for image processing operations",
        Contact = new OpenApiContact
        {
            Name = "Support",
            Email = "support@example.com"
        }
    });
    
    // Inclure les commentaires XML
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    c.IncludeXmlComments(xmlPath);
});

// Middleware
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Image Processor API V1");
});
```

## 4. Interface en Ligne de Commande (CLI)

### 4.1 Architecture CLI

```cpp
class CommandLineInterface {
public:
    int execute(int argc, char* argv[]);
    
private:
    void registerCommands();
    Command* parseCommand(int argc, char* argv[]);
    void displayHelp();
    void displayVersion();
};
```

### 4.2 Commandes principales

#### **4.2.1 Filter command**

```bash
imageproc filter --input image.png --output result.png --type gaussian-blur --radius 5
```

#### **4.2.2 Resize command**

```bash
imageproc resize --input image.jpg --output resized.jpg --width 800 --height 600
```

#### **4.2.3 Convert command**

```bash
imageproc convert --input image.bmp --output image.png --quality 95
```

#### **4.2.4 Batch command**

```bash
imageproc batch --input "*.jpg" --output processed/ --filter brightness --value 1.2
```

#### **4.2.5 Info command**

```bash
imageproc info --input image.png
# Output:
# Width: 1920
# Height: 1080
# Format: PNG
# Color: RGBA
# Size: 8294400 bytes
```

### 4.3 Implémentation CLI

```cpp
#include <cxxopts.hpp>

int CommandLineInterface::execute(int argc, char* argv[]) {
    cxxopts::Options options("imageproc", "Image processing tool");
    
    options.add_options()
        ("h,help", "Print help")
        ("v,version", "Print version")
        ("command", "Command to execute", cxxopts::value<std::string>())
        ;
    
    options.parse_positional({"command"});
    
    auto result = options.parse(argc, argv);
    
    if (result.count("help")) {
        displayHelp();
        return 0;
    }
    
    if (result.count("version")) {
        displayVersion();
        return 0;
    }
    
    if (result.count("command")) {
        std::string command = result["command"].as<std::string>();
        return executeCommand(command, argc, argv);
    }
    
    std::cerr << "No command specified. Use --help for usage." << std::endl;
    return 1;
}
```

## 5. Compatibilité Multilangage

### 5.1 Interopérabilité C ↔ C++

```cpp
// Header C (pixel_ops.h)
#ifdef __cplusplus
extern "C" {
#endif

void process_pixels(uint8_t* data, size_t size, float factor);

#ifdef __cplusplus
}
#endif

// Utilisation en C++
#include "pixel_ops.h"

void ImageProcessor::adjustBrightness(float factor) {
    process_pixels(image_.data(), image_.size(), factor);
}
```

### 5.2 Interopérabilité C/C++ ↔ C#

#### **5.2.1 Export C**

```c
// imageproc_c_api.h
#ifdef __cplusplus
extern "C" {
#endif

typedef void* ImageHandle;

EXPORT ImageHandle imageproc_load_image(const char* path);
EXPORT int imageproc_apply_filter(ImageHandle handle, const char* filter, void* params);
EXPORT int imageproc_save_image(ImageHandle handle, const char* path);
EXPORT void imageproc_free_image(ImageHandle handle);

#ifdef __cplusplus
}
#endif
```

#### **5.2.2 Import C#**

```csharp
public static class NativeImageProcessor
{
    [DllImport("imageproc", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr imageproc_load_image(
        [MarshalAs(UnmanagedType.LPStr)] string path);
    
    [DllImport("imageproc", CallingConvention = CallingConvention.Cdecl)]
    public static extern int imageproc_apply_filter(
        IntPtr handle,
        [MarshalAs(UnmanagedType.LPStr)] string filter,
        IntPtr parameters);
    
    [DllImport("imageproc", CallingConvention = CallingConvention.Cdecl)]
    public static extern int imageproc_save_image(
        IntPtr handle,
        [MarshalAs(UnmanagedType.LPStr)] string path);
    
    [DllImport("imageproc", CallingConvention = CallingConvention.Cdecl)]
    public static extern void imageproc_free_image(IntPtr handle);
}
```

#### **5.2.3 Wrapper C# sécurisé**

```csharp
public class ImageProcessor : IDisposable
{
    private IntPtr _handle;
    private bool _disposed = false;
    
    public ImageProcessor(string path)
    {
        _handle = NativeImageProcessor.imageproc_load_image(path);
        if (_handle == IntPtr.Zero)
            throw new Exception("Failed to load image");
    }
    
    public void ApplyFilter(string filterName, object parameters)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(ImageProcessor));
        
        IntPtr paramsPtr = MarshalParameters(parameters);
        try
        {
            int result = NativeImageProcessor.imageproc_apply_filter(
                _handle, filterName, paramsPtr);
            if (result != 0)
                throw new Exception($"Filter failed with code {result}");
        }
        finally
        {
            Marshal.FreeHGlobal(paramsPtr);
        }
    }
    
    public void Save(string path)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(ImageProcessor));
        
        int result = NativeImageProcessor.imageproc_save_image(_handle, path);
        if (result != 0)
            throw new Exception("Failed to save image");
    }
    
    public void Dispose()
    {
        if (!_disposed && _handle != IntPtr.Zero)
        {
            NativeImageProcessor.imageproc_free_image(_handle);
            _handle = IntPtr.Zero;
            _disposed = true;
        }
        GC.SuppressFinalize(this);
    }
    
    ~ImageProcessor()
    {
        Dispose();
    }
}
```

### 5.3 Gestion des erreurs inter-langages

```c
// Code d'erreur standardisé
typedef enum {
    SUCCESS = 0,
    ERROR_INVALID_PARAM = 1,
    ERROR_OUT_OF_MEMORY = 2,
    ERROR_FILE_NOT_FOUND = 3,
    ERROR_UNSUPPORTED_FORMAT = 4,
    ERROR_INTERNAL = 5
} ErrorCode;

// Obtenir le dernier message d'erreur
EXPORT const char* imageproc_get_last_error(void);
```

```csharp
public static class ErrorHandling
{
    [DllImport("imageproc")]
    private static extern IntPtr imageproc_get_last_error();
    
    public static string GetLastError()
    {
        IntPtr ptr = imageproc_get_last_error();
        return Marshal.PtrToStringAnsi(ptr);
    }
    
    public static void CheckError(int errorCode)
    {
        if (errorCode != 0)
        {
            string message = GetLastError();
            throw new ImageProcessingException(errorCode, message);
        }
    }
}
```

## 6. Best Practices

### 6.1 Plugins
- Toujours valider la version de l'API
- Timeout pour éviter blocages
- Exception handling robuste
- Documentation claire des paramètres
- Exemples de code fournis

### 6.2 API REST
- Versioning de l'API (v1, v2)
- Rate limiting pour éviter abus
- Validation stricte des entrées
- Documentation OpenAPI complète
- HTTPS obligatoire en production

### 6.3 CLI
- Messages d'erreur clairs
- Progress bars pour opérations longues
- Exit codes standardisés
- Support pipes Unix
- Colorisation optionnelle

### 6.4 Interopérabilité
- ABI C stable pour exports
- Blittable types pour marshalling
- RAII / IDisposable pour gestion ressources
- Documentation des conventions d'appel
- Tests d'interop exhaustifs

## Conclusion

Ce référentiel technique fournit tous les éléments nécessaires pour :
- Développer des plugins compatibles
- Intégrer l'API REST dans des applications tierces
- Utiliser la CLI pour automatisation
- Assurer l'interopérabilité entre C, C++ et C#

Les exemples de code et les best practices garantissent une implémentation cohérente et maintenable.
