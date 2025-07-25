# gdParameterSync Development Setup

This repository contains the gdParameterSync addon and a demo project for development.

## Structure

```
gdParameterSync/
├── addons/
│   └── gdParameterSync/           # The actual addon
│       ├── plugin.cfg
│       ├── plugin.gd
│       ├── core/                  # Core system classes
│       │   ├── parameter_sync.gd  # Main facade (autoload)
│       │   ├── parameter_store.gd # Parameter storage & management
│       │   ├── messaging_router.gd # Message routing between backends
│       │   ├── preset_manager.gd  # Preset save/load (stub)
│       │   └── binding_manager.gd # Node property bindings (stub)
│       ├── resources/             # TRES resource classes
│       │   ├── parameter_set.gd
│       │   ├── parameter_group.gd
│       │   ├── parameter.gd
│       │   └── parameter_binding.gd
│       ├── backends/              # Protocol backends
│       │   └── debug_backend.gd   # Simple debug backend
│       └── ui/                    # UI components (TODO)
├── gdparametersync-demo/          # Demo project
│   ├── addons -> ../addons        # Symlink to addon for development
│   ├── demo.tscn                  # Demo scene
│   ├── demo_fixed.gd              # Demo script
│   ├── example_parameters.tres    # Example parameter set
│   └── project.godot              # Project with ParameterSync autoload
└── README.md                      # This file
```

## Development Workflow

### For Users (Submodule in Addon Folder)
1. Add this repo as a submodule in your project's `addons/` folder:
   ```bash
   cd your_project/addons/
   git submodule add https://github.com/your-username/gdParameterSync.git
   ```

2. Enable the "gdParameterSync" plugin in your project settings.

3. The `ParameterSync` autoload will be available globally.

### For Development
1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/gdParameterSync.git
   cd gdParameterSync
   ```

2. Open the demo project in Godot:
   ```bash
   godot gdparametersync-demo/project.godot
   ```

3. The demo project has a symlink to the addon, so changes to the addon are immediately reflected.

## Current Implementation Status

### ✅ Implemented (v0.1)
- Core resource classes (Parameter, ParameterGroup, ParameterSet, ParameterBinding)
- Parameter validation and type conversion
- ParameterStore for managing parameter values
- MessagingRouter for routing messages between backends
- Basic debug backend for testing
- Autoload facade (ParameterSync)
- Demo project with working examples

### 🚧 In Progress
- Preset saving/loading
- Node property bindings
- UI panel generation

### 📋 TODO (Future Versions)
- OSC backend (using vendored godOSC)
- OSCQuery HTTP backend
- OSCQuery WebSocket backend
- MIDI backend
- Zeroconf/mDNS discovery
- Web UI generation
- Advanced UI components

## Quick Start

1. Open the demo project in Godot
2. Run the scene (F6)
3. Click "Create Test ParameterSet" to create parameters programmatically
4. Click "Load Example TRES" to load a parameter set from a .tres file
5. Use the slider to change parameter values
6. Watch the log for parameter change events

## API Examples

### Creating Parameters Programmatically

```gdscript
# Create a parameter set
var param_set = ParameterSet.new("audio", "Audio Parameters")

# Create a parameter
var volume_param = Parameter.new("volume", TYPE_FLOAT, 0.75)
volume_param.min_value = 0.0
volume_param.max_value = 1.0
volume_param.step = 0.01
volume_param.description = "Master volume control"

# Add to set and register
param_set.parameters.append(volume_param)
ParameterSync.register_set(param_set)
```

### Using Parameter Values

```gdscript
# Set a parameter value
ParameterSync.set_value("audio", "volume", 0.8)

# Get a parameter value  
var volume = ParameterSync.get_value("audio", "volume")

# Listen for changes
ParameterSync.parameter_changed.connect(_on_parameter_changed)
```

### Creating TRES Resources

You can also create ParameterSet resources in the Godot editor and save them as .tres files. See `example_parameters.tres` for a reference.

## Design Principles

1. **TRES as Single Source of Truth**: Everything (UI, OSC, WebSocket, MIDI) is generated from ParameterSet.tres files
2. **No Duplication**: Define parameters once, generate everything else
3. **Clean Architecture**: Separation of concerns with pluggable backends
4. **Pure GDScript**: No native dependencies, works in exports
5. **Standards Compliant**: Full OSCQuery and OSC compatibility

## Contributing

1. Make changes to files in `addons/gdParameterSync/`
2. Test in the demo project 
3. Add tests and examples as needed
4. Follow the established architecture patterns
