@tool
extends MarginContainer
## A workspace host for registered editing contexts and category panels.

const EditorContext := preload("res://addons/ldk/core/UI/editor/content_editor_context.gd")
const SettingsView := preload("res://addons/ldk/core/UI/editor/content_editor_settings.gd")

@onready var _tabs: TabBar = %Tabs
@onready var _config_button: Button = %Config
@onready var _settings: SettingsView = %Settings
@onready var _panel_host: PanelContainer = %Panels
@onready var _toolbar: HBoxContainer = %Toolbar
@onready var _no_sources: Label = %NoSources
@onready var _warnings: Button = %Warnings
@onready var _reload_button: Button = %Refresh
@onready var _diagnostics: TextEdit = %Diagnostics

var _contexts: Array[EditorContext] = []
var _context: EditorContext
var _category_ids: Array[StringName] = []
var _panels: Array[Control] = []
var _refreshers: Array[Callable] = []
var _rendered_revisions: Dictionary[int, int] = {}
var _status_revision := -1
var _visible_panel: Control


func _ready() -> void:
	_tabs.tab_selected.connect(_select_tab)
	_config_button.toggled.connect(_show_settings)
	_settings.context_selected.connect(_select_context)
	_settings.closed.connect(_show_settings.bind(false))
	_warnings.pressed.connect(_show_diagnostics)
	_reload_button.pressed.connect(_reload)
	visibility_changed.connect(_refresh_active)


func register_context(context: EditorContext) -> bool:
	if context == null or context.id.is_empty():
		return false
	for existing in _contexts:
		if existing.id == context.id:
			return false
	_contexts.append(context)
	_settings.add_context(context.title)
	_config_button.disabled = false
	_reload_button.disabled = false
	if _context == null:
		_select_context(0)
		_refresh_active()
	return true


func register_category(id: StringName, title: String, panel: Control, refresh := Callable()) -> bool:
	if id.is_empty() or id in _category_ids or panel == null or panel.get_parent() != null:
		return false
	_category_ids.append(id)
	_panels.append(panel)
	_refreshers.append(refresh)
	panel.hide()
	_panel_host.add_child(panel)
	_tabs.add_tab(title)
	_refresh_active()
	return true


func _select_context(index: int) -> void:
	var context := _contexts[index]
	if _context != context:
		_context = context
		_rendered_revisions.clear()
		_status_revision = -1
	_settings.show_context(index, context)


func _select_tab(_index: int) -> void:
	if _settings.visible:
		_show_settings(false)
	else:
		_refresh_active()


func _show_settings(open: bool) -> void:
	_config_button.set_pressed_no_signal(open)
	_settings.visible = open
	_panel_host.visible = not open
	if open:
		_toolbar.hide()
		_settings.show_context(_contexts.find(_context), _context)
	else:
		_refresh_active()


func _refresh_active() -> void:
	if not is_visible_in_tree() or _settings.visible or _context == null:
		return
	var index := _tabs.current_tab
	if index < 0:
		return
	var panel := _panels[index]
	if _visible_panel != panel:
		if _visible_panel != null:
			_visible_panel.hide()
		_visible_panel = panel
		panel.show()
	var revision := _context.revision
	if _rendered_revisions.get(index, -1) != revision:
		_context.ensure_loaded()
		var refresh := _refreshers[index]
		if refresh.is_valid():
			refresh.call(_context)
		_rendered_revisions[index] = revision
	if _status_revision != revision:
		_no_sources.visible = _context.read_directories.is_empty()
		var warning_count := _context.issues.size() + int(not _context.settings_issue.is_empty())
		_warnings.visible = warning_count > 0
		_warnings.text = "Avisos (%d)" % warning_count
		_status_revision = revision
	_toolbar.visible = _no_sources.visible or _warnings.visible


func _reload() -> void:
	_context.invalidate_sources()
	_context.ensure_loaded()
	_refresh_active()


func _show_diagnostics() -> void:
	var messages := _context.issues.duplicate()
	if not _context.settings_issue.is_empty():
		messages.insert(0, _context.settings_issue)
	_diagnostics.text = "\n\n".join(messages)
	%WarningsDialog.popup_centered()
