# **gdParameterSync — SDR (Clean, Modular, **TRES-as-the-only source of truth**)**

**Engine:** Godot 4.4  **Lang:** 100% GDScript
**Dependencies:** None native. **godOSC is vendored GDScript.**
**Design mantra:** **Everything (UI, OSC/OSCQuery tree, Web UI, MIDI/OSC mappings, presets) is *generated from the TRES* — once.**

---

## 🚀 Quick Start (Automatic UI Generation)

The easiest way to get started is with automatic UI generation:

```gdscript
extends Control

func _ready():
    # Create the UI generator
    var ui_generator = load("res://addons/gdParameterSync/ui/parameter_ui_generator.gd").new()
    add_child(ui_generator)
    
    # Generate complete UI from any TRES file - that's it!
    ui_generator.generate_ui_from_tres("res://my_parameters.tres")
    
    # Optional: Listen to parameter changes
    ui_generator.parameter_changed.connect(_on_parameter_changed)

func _on_parameter_changed(set_id: String, param_name: String, value, source: String):
    print("Parameter changed: ", param_name, " = ", value)
```

The addon automatically creates:
- ✅ **Sliders + spinboxes** for numeric parameters
- ✅ **Option menus** with descriptive labels (Triangle, Square, etc.)
- ✅ **Color pickers** with preview rectangles
- ✅ **Checkboxes** for boolean parameters  
- ✅ **Vector controls** with X/Y spinboxes
- ✅ **Foldable groups** organized by parameter types
- ✅ **Built-in type safety** with automatic type conversion
- ✅ **Reset functionality** that handles all parameter types correctly

## ⭐ Enhanced Type Safety

**✅ Type safety is now built into the addon!** The `get_value()` method automatically:

- **Validates parameter types** and returns factory values for type mismatches
- **Converts compatible types** intelligently (String ↔ int/float/bool/Vector2/Color)
- **Prevents runtime errors** like "Invalid operands 'String' and 'Color'"
- **Makes reset functionality robust** without manual type checking

```gdscript
# Simple, safe parameter access - no manual type checking needed!
var color = param_sync.get_value("my_set", "fill_color")  # Always returns proper Color
var sides = param_sync.get_value("my_set", "sides")       # Always returns proper int
```

---

## 0) Core principleameterSync — SDR (Clean, Modular, **TRES-as-the-only source of truth**)**

**Engine:** Godot 4.4  **Lang:** 100% GDScript
**Dependencies:** None native. **godOSC is vendored GDScript.**
**Design mantra:** **Everything (UI, OSC/OSCQuery tree, Web UI, MIDI/OSC mappings, presets) is *generated from the TRES* — once.**

---

## 0) Core principle

> **Define parameters once in a `ParameterSet.tres`.**
> From that single definition, gdParameterSync **generates**:

* The **in‑game floating UI** (panel, groups, widgets),
* The **OSC address space**,
* The **OSCQuery HTTP/WS JSON tree**,
* The **WebSocket JSON schema**,
* The **MIDI/OSC learn maps’ shapes**,
* The **factory vs user preset structure**,
* The **discovery metadata** (mDNS TXT).

No duplication. No hand-written schemas. **TRES = schema + factory values.**

---

## 1) Resource model (authoring level)

All authored as `.tres` (or `.res`) and loaded at runtime.

### `ParameterSet` (root, one per logical block)

```gdscript
@export var id: String                   # unique, used in paths & discovery
@export var label: String
@export var groups: Array[ParameterGroup]
@export var parameters: Array[Parameter] # optional top-level params
@export var preset_policy: int           # FACTORY_ONLY | USER_OVERRIDE | USER_ONLY
@export var bindings: Array[ParameterBinding]
@export var meta: Dictionary             # tags, units, etc. (feeds OSCQuery optional attrs)
```

### `ParameterGroup`

```gdscript
@export var name: String
@export var groups: Array[ParameterGroup]
@export var parameters: Array[Parameter]
@export var folded_by_default: bool = true
```

### `Parameter`

```gdscript
@export var name: String
@export var type: int                    # Variant.Type
@export var value: Variant               # factory value
@export var min: Variant
@export var max: Variant
@export var step: float = 0.0
@export var enum_values: Array           # -> OSCQuery RANGE.VALS
@export var ui_hints: Dictionary         # extended_type, unit, clipmode, log, etc.
@export var read_only: bool = false
@export var address_override: String     # overrides auto /gdps/<...> address
@export var backend_meta: Dictionary     # midi_cc, osc paths, overloads, etc.
@export var description: String
```

### `ParameterBinding`

```gdscript
@export var parameter_path: String       # inside the set
@export var node: NodePath
@export var property: String
@export var transform_to_node: Callable
@export var transform_from_node: Callable
```

---

## 2) Generated artifacts (from the TRES)

| Artifact              | Generated from                    | Notes                                                                                           |
| --------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------- |
| **Panel UI**          | `ParameterSet` → groups / params  | Widgets chosen by `type` (+ `ui_hints`).                                                        |
| **OSC address space** | `ParameterSet` tree               | `/gdps/<set_id>/<group>/<param>` or `address_override`.                                         |
| **OSCQuery HTTP/WS**  | same                              | Required + optional attributes built from the same fields (`min/max/vals`, `ui_hints`, `meta`). |
| **Web UI (optional)** | same JSON                         | Vanilla HTML/JS reflects tree.                                                                  |
| **Presets JSON**      | values diff vs factory            | Stored per‑set in `user://gdps/presets/<set_id>/...json`.                                       |
| **MIDI map**          | `backend_meta` or learned         | Stored in `user://gdps/mappings/<set_id>.json`.                                                 |
| **Discovery TXT**     | from set ids + ports + EXTENSIONS | Advertised via mDNS `_oscjson._tcp`.                                                            |

---

## 3) Modules (clean & minimal responsibilities)

### 3.1 Core

**`ParameterSync` (AutoLoad)**
Public façade; owns the other services. Only entry point you call.

**`ParameterStore`**

* Registers `ParameterSet` TRESes.
* Applies **source-of-truth rule** (user preset > factory).
* Emits `parameter_changed`.

**`MessagingRouter`**

* Central bus for value changes.
* Tags sources (`local`, `osc`, `ws`, `midi`, `oscquery_ws`) to avoid echo loops.
* Dispatches to all active backends.

**`PresetManager`**

* Saves/loads diffs vs factory.
* Returns dirty flags.

**`BindingManager`**

* Applies param changes to bound nodes and vice versa.

### 3.2 Backends (all GDScript)

Every backend implements a minimal interface:

```gdscript
class_name GDPSBackend
signal connected()
signal disconnected()
signal message_in(path: String, value: Variant, meta := {})

func configure(cfg: Dictionary) -> void
func start() -> void
func stop() -> void
func send(path: String, value: Variant) -> void
func is_running() -> bool
```

* **OSCBackend (vendored godOSC)** – UDP server/client.
* **WSBackend (JSON)** – simple JSON protocol (optional legacy).
* **MidiBackend** – via `InputEventMIDI`.
* **OSCQueryBackend**

  * `oscquery_http.gd` (HTTP 1.1, attribute queries, host info)
  * `oscquery_ws.gd` (LISTEN/IGNORE, PATH\_\* notifications, raw OSC binary)
  * `oscquery_descriptor.gd` (TRES → JSON per spec)
* **ZeroconfBackend** – minimal mDNS for `_oscjson._tcp` announce/browse.

### 3.3 UI

**`ParameterPanel`** (`Window`)

* Adds/removes `ParameterSet`s.
* Per‑set toolbar: **reset, save, load, sync toggle, MIDI/OSC learn**.
* Search, fold/unfold.
* Emits signals on user actions; never talks to backends directly.

**`WidgetFactory`**
(type → editor Control): bool, int/float, enum, color, vectors, arrays/dicts (modal), etc.

---

## 4) Runtime flow (end‑to‑end)

1. **Load TRES** → `ParameterSync.register_set(tres)`.
2. **PresetManager** checks for user preset; applies to Store.
3. **Store** builds internal tree & signals `set_registered`.
4. **Panel** (if present) asks `describe_set()` and **renders** UI.
5. **OSCQueryBackend** asks `oscquery_descriptor` to **serve JSON** for the same tree.
6. Messages from UI / OSC / WS / MIDI hit **MessagingRouter → Store** →

   * Panel updates widgets,
   * **OSCQuery WS** pushes RAW OSC to all LISTENers,
   * Node bindings update properties.

Everything mirrors the **same TRES**.

---

## 5) Public API (thin & TRES-first)

```gdscript
class_name ParameterSync
extends Node

signal set_registered(set_id: String)
signal set_unregistered(set_id: String)
signal parameter_changed(set_id: String, path: String, value: Variant, source: String)
signal preset_saved(set_id: String, name: String)
signal preset_loaded(set_id: String, name: String)
signal server_discovered(info: Dictionary)
signal server_lost(info: Dictionary)

# TRES
func register_set(param_set: ParameterSet) -> void
func unregister_set(set_id: String) -> void

# Values
func get_value(set_id: String, param_path: String) -> Variant
func set_value(set_id: String, param_path: String, value: Variant, source := "local") -> void

# Presets
func save_user_preset(set_id: String, name := "latest.json") -> void
func load_user_preset(set_id: String, name := "latest.json") -> void
func reset_to_factory(set_id: String) -> void

# Describe (feeds UI, OSCQuery, WS clients)
func describe_set(set_id: String) -> Dictionary
func describe_all() -> Dictionary
func describe_path_oscquery(path: String, attributes := PackedStringArray()) -> Dictionary
func host_info() -> Dictionary

# Backends
func enable_backend(name: String, cfg := {}) -> void
func disable_backend(name: String) -> void
func is_backend_enabled(name: String) -> bool

# Zeroconf
func zeroconf_start(service_name := "gdParameterSync", domain := "local") -> void
func zeroconf_stop() -> void
func zeroconf_scan(timeout_sec := 2.0) -> Array[Dictionary]

# Bindings
func bind_parameter(set_id: String, param_path: String, node: NodePath, property: String, opts := {}) -> void
func unbind_parameter(set_id: String, param_path: String, node: NodePath, property: String) -> void
```

---

## 6) OSCQuery compatibility (concise rules)

* **HTTP**

  * `GET /path` → full JSON of node + `CONTENTS`.
  * `GET /path?VALUE|RANGE|TYPE|ACCESS|...` → attribute subset (204/400/404 respected).
  * `GET /anything?HOST_INFO` → server meta (`EXTENSIONS`, ports, etc.).

* **WS**

  * **Text JSON**: `LISTEN`, `IGNORE`, `PATH_CHANGED`, `PATH_ADDED`, `PATH_REMOVED`, `PATH_RENAMED`.
  * **Binary**: raw OSC frames (godOSC encode/decode).
  * Only nodes previously `LISTEN`’d stream values.

* **Optional attributes** are computed from `Parameter`’s fields & `ui_hints`/`meta`.

---

## 7) Discovery (mDNS)

* Advertise `_oscjson._tcp.local.` with:

  * **SRV**: hostname + HTTP port
  * **TXT**: `name`, `osc_port`, `ws_port`, `supports=value,range,...`
* Browse & emit `server_discovered` with parsed TXT & addr.
* Pure GDScript implementation (basic IPv4, single NIC, simple TTL).

---

## 8) Security

* Token-based writes: `?token=...` or `Authorization: Bearer`.
* Bind localhost by default.
* No TLS (leave to reverse proxy).
* Option to disable discovery.

---

## 9) Roadmap (TRES‑first milestones)

**v1.0**

* TRES → UI/OSC/WebSocket(JSON)/MIDI, presets, bindings, MessagingRouter, Panel.

**v1.1**

* **OSCQuery HTTP (core attrs)** 100% generated from TRES.

**v1.2**

* **OSCQuery optional attrs** + **WebSocket bi‑dir** + raw OSC streaming.

**v1.3**

* **mDNS Zeroconf** announce/browse; discovery UI.

**v1.4**

* Undo/redo, automation record/play, float throttling, array/dict rich editors.

---

## 10) Acceptance (all “from TRES”)

* [ ] Creating/modifying a `ParameterSet.tres` **changes UI, OSC, OSCQuery JSON, WS, MIDI** automatically — no extra code.
* [ ] `?HOST_INFO` accurately reflects supported optional attrs.
* [ ] `LISTEN/IGNORE` and PATH\_\* notifications work.
* [ ] mDNS announce/browse functional (fallback manual).
* [ ] Preset diff vs factory OK; source-of-truth precedence respected.
* [ ] 100% GDScript, works in exports & headless.
