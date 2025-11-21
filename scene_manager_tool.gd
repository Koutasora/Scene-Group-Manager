# filename: scene_manager_tool.gd
@tool
extends EditorPlugin

# This array will hold our group structure:
# [
#   { "name": "UI", "index": 0, "scenes": ["res://scenes/main_menu.tscn"] },
#   { "name": "Levels", "index": 1, "scenes": ["res://scenes/world_1.tscn", "res://scenes/world_2.tscn"] }
# ]
const PROJECT_SETTING_PATH = "application/config/scene_groups"
var scene_groups: Array = []

var manager_control: Control = null
var group_list: VBoxContainer = null
var add_group_line_edit: LineEdit = null

# --- Plugin Lifecycle Methods ---

func _enter_tree():
	# DEBUG: Print immediately to see if the plugin is running at all
	print("Scene Group Manager: Plugin STARTING _enter_tree()")
	
	# 1. Load or initialize scene groups from Project Settings
	_load_groups()
	
	# 2. Create the custom UI dock
	manager_control = _create_manager_ui()
	
	# 3. Add the control as a persistent Dock panel (DOCK_SLOT_LEFT_BR is typically bottom-right)
	add_control_to_dock(DOCK_SLOT_LEFT_BR, manager_control)
	
	# FIX: Defer the initial UI update until the editor has fully configured the dock panel
	call_deferred("_update_group_list_ui")


func _exit_tree():
	# Clean up on exit
	if manager_control:
		remove_control_from_docks(manager_control)
		manager_control.queue_free()

func _get_plugin_name():
	return "Scene Group Manager"

func _has_main_screen():
	return false

func _is_initialized():
	return true
	
func _make_visible(visible):
	pass

# --- Persistence and Data Management ---

func _load_groups():
	# Ensure the setting exists, initialize if not.
	if not ProjectSettings.has_setting(PROJECT_SETTING_PATH):
		ProjectSettings.set_setting(PROJECT_SETTING_PATH, [])
		ProjectSettings.set_initial_value(PROJECT_SETTING_PATH, [])
	
	# Load the groups and sort them by index (0 is top)
	scene_groups = ProjectSettings.get_setting(PROJECT_SETTING_PATH, []).duplicate()
	scene_groups.sort_custom(func(a, b): return a.index < b.index)
	print("Scene Group Manager: Loaded %d groups." % scene_groups.size())

func _save_groups():
	# Save the current state of scene_groups back to Project Settings
	ProjectSettings.set_setting(PROJECT_SETTING_PATH, scene_groups)
	ProjectSettings.save()
	_update_group_list_ui() # Update the UI to reflect changes immediately after saving

# --- UI Creation ---

func _create_manager_ui() -> Control:
	var control = Control.new()
	control.set_name("SceneGroupManagerControl")
	# TWEAK: Set a larger minimum size to prevent the dock from collapsing awkwardly.
	control.set_custom_minimum_size(Vector2(250, 400)) 
	control.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	control.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	
	var vbox = VBoxContainer.new()
	vbox.set_name("MainVBox")
	vbox.add_theme_constant_override("separation", 10) # Reduced separation slightly
	vbox.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	vbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	# IMPROVEMENT: Removed the hardcoded MarginContainer. 
	# Docks usually handle padding automatically or through the root VBox.
	control.add_child(vbox) 
	
	# Title
	var title_label = Label.new()
	title_label.text = "Scene Group Assignments"
	# TWEAK: Adjusting font size and color for better appearance
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)
	
	# Group List Container (where groups are displayed)
	var scroll_container = ScrollContainer.new()
	scroll_container.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	scroll_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	scroll_container.set_custom_minimum_size(Vector2(0, 300))
	# CRITICAL FIX: Ensure horizontal scroll is disabled. We must ensure the child (group_list)
	# expands horizontally to the container width, which SIZE_EXPAND_FILL handles.
	scroll_container.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	vbox.add_child(scroll_container)
	
	group_list = VBoxContainer.new()
	group_list.add_theme_constant_override("separation", 20) 
	# CRITICAL SIZING FIX: EXPAND and FILL horizontally to force it to match ScrollContainer width
	group_list.set_h_size_flags(Control.SIZE_EXPAND_FILL) 
	group_list.set_v_size_flags(Control.SIZE_SHRINK_BEGIN) 
	scroll_container.add_child(group_list)
	
	# --- Add Group Section ---
	
	# Separator
	vbox.add_child(HSeparator.new())
	
	# NEW FEATURE: Unload All Button
	var unload_all_button = Button.new()
	unload_all_button.text = "Unload ALL Scenes"
	# TWEAK: Added Control.SIZE_FILL flag for extra measure on expansion
	unload_all_button.set_h_size_flags(Control.SIZE_EXPAND_FILL | Control.SIZE_FILL) 
	# TWEAK: Set a color for visual distinction
	unload_all_button.add_theme_color_override("font_color", Color("f44336")) 
	unload_all_button.connect("pressed", Callable(self, "_on_unload_all_scenes_pressed"))
	vbox.add_child(unload_all_button)

	var add_hbox = HBoxContainer.new()
	# UI FIX: Ensure HBoxContainer expands to utilize full dock width
	add_hbox.set_h_size_flags(Control.SIZE_EXPAND_FILL) 
	vbox.add_child(add_hbox)
	
	add_group_line_edit = LineEdit.new()
	add_group_line_edit.placeholder_text = "New Group Name"
	# UI FIX: Ensure LineEdit expands to fill available space in the HBox
	add_group_line_edit.set_h_size_flags(Control.SIZE_EXPAND_FILL) 
	add_hbox.add_child(add_group_line_edit)
	
	var add_button = Button.new()
	add_button.text = "Add"
	# TWEAK: Ensures button size is minimal, allowing LineEdit to take the rest
	add_button.set_h_size_flags(Control.SIZE_SHRINK_BEGIN) 
	add_button.connect("pressed", Callable(self, "_on_add_group_pressed"))
	add_hbox.add_child(add_button)

	return control

# --- UI Update and Group Display ---

func _update_group_list_ui():
	# Clear existing children
	for child in group_list.get_children():
		child.queue_free()

	# Create UI elements for each group
	for group_array_index in range(scene_groups.size()):
		var group = scene_groups[group_array_index]
		
		print("Scene Group Manager: Rendering group: %s (Index %d)" % [group.name, group.index])
		
		# 1. Group Box for Structure and Padding
		var group_box = VBoxContainer.new()
		group_box.add_theme_constant_override("separation", 3)
		# UI FIX: Force group_box to expand horizontally
		group_box.set_h_size_flags(Control.SIZE_EXPAND_FILL) 
		
		# 2. Group Name and Index (e.g., [0] UI)
		var label = Label.new()
		# TWEAK: Make the label bolder and slightly bigger to emulate Godot structure titles
		label.text = "[%d] %s" % [group.index, group.name.to_upper()]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("f0e68c"))
		group_box.add_child(label)
		
		# 3. List of assigned scenes
		if group.scenes.is_empty():
			var scene_label = Label.new()
			scene_label.text = " (No scenes assigned)"
			scene_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
			group_box.add_child(scene_label)
		else:
			# Scene Listing VBox
			var scene_list_vbox = VBoxContainer.new()
			scene_list_vbox.add_theme_constant_override("separation", 2)
			# UI FIX: Force scene_list_vbox to expand horizontally
			scene_list_vbox.set_h_size_flags(Control.SIZE_EXPAND_FILL) 
			group_box.add_child(scene_list_vbox)
			
			for scene_list_index in range(group.scenes.size()):
				var scene_path = group.scenes[scene_list_index]
				
				# Container for a single scene path and its remove button
				var scene_hbox = HBoxContainer.new()
				scene_hbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)
				
				# UI FIX: Use a Label for display and a separate Button for opening.
				var scene_name_label = Label.new()
				# Show only the file name, and use the full path as a tooltip
				scene_name_label.text = scene_path.get_file().get_basename() 
				scene_name_label.tooltip_text = "Click to open: " + scene_path
				# TWEAK: Label must expand to take up all leftover space in HBox
				scene_name_label.set_h_size_flags(Control.SIZE_EXPAND_FILL)
				scene_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				scene_hbox.add_child(scene_name_label)
				
				# NEW: Button to open the scene in the editor
				var open_scene_button = Button.new()
				open_scene_button.text = "Open"
				open_scene_button.tooltip_text = "Open scene file"
				open_scene_button.set_h_size_flags(Control.SIZE_SHRINK_BEGIN) # Keep small
				open_scene_button.connect("pressed", Callable(self, "_on_scene_path_pressed").bind(scene_path))
				scene_hbox.add_child(open_scene_button)
				
				# Separate Scene Remove Button
				var remove_scene_button = Button.new()
				remove_scene_button.text = "X"
				remove_scene_button.tooltip_text = "Remove scene from group"
				remove_scene_button.set_h_size_flags(Control.SIZE_SHRINK_BEGIN) # Keep small
				remove_scene_button.add_theme_color_override("font_color", Color.RED)
				remove_scene_button.connect("pressed", Callable(self, "_on_remove_scene_from_group_pressed").bind(group_array_index, scene_list_index))
				scene_hbox.add_child(remove_scene_button)
				
				scene_list_vbox.add_child(scene_hbox)
		
		# 4. Action Button (Toggle Scene Assignment)
		var assign_button = Button.new()
		assign_button.text = "Toggle Current Scene Assignment"
		# CRITICAL SIZING: Force button to expand horizontally
		assign_button.set_h_size_flags(Control.SIZE_EXPAND_FILL | Control.SIZE_FILL) 
		assign_button.connect("pressed", Callable(self, "_on_assign_scene_pressed").bind(group_array_index))
		group_box.add_child(assign_button)
		
		# 5. Remove Group Button 
		var remove_group_button = Button.new()
		remove_group_button.text = "Remove Entire Group"
		# CRITICAL SIZING: Force button to expand horizontally
		remove_group_button.set_h_size_flags(Control.SIZE_EXPAND_FILL | Control.SIZE_FILL) 
		remove_group_button.add_theme_color_override("font_color", Color.RED)
		remove_group_button.connect("pressed", Callable(self, "_on_remove_group_pressed").bind(group_array_index))
		group_box.add_child(remove_group_button)

		# Add a separator AFTER the group box for visual distinction
		var h_separator = HSeparator.new()
		h_separator.set_custom_minimum_size(Vector2(0, 5))
		
		group_list.add_child(group_box)
		group_list.add_child(h_separator)
		

# --- Signal Handlers (The Logic) ---

func _on_unload_all_scenes_pressed():
	# Iterate over all scene groups
	for group in scene_groups:
		var scenes_to_unload = group.scenes
		
		print("Scene Group Manager: Unloading scenes for group [%d] %s" % [group.index, group.name])
		
		# Use a separate helper function to handle the actual unloading logic
		print("INFO: Unloading is a runtime action. When using the 'scene_group_loader.gd' script, all assigned scenes for this group would be unloaded from the SceneTree.")
	
	print("Unload All Scenes action completed (This is a runtime action and only affects the SceneTree when the game is running).")


func _on_scene_path_pressed(scene_path: String):
	var resource = load(scene_path)
	if resource:
		get_editor_interface().edit_resource(resource)
	else:
		push_error("Could not load scene resource at path: " + scene_path)
	
func _on_remove_scene_from_group_pressed(group_array_index: int, scene_list_index: int):
	# Fetch the group object
	var group = scene_groups[group_array_index]
	
	# Remove the scene path from the group's scene list
	group.scenes.remove_at(scene_list_index)
	print("Scene removed from group [%d] %s" % [group.index, group.name])
	
	_save_groups() # Save and update UI

func _on_add_group_pressed():
	var new_name = add_group_line_edit.text.strip_edges()
	if new_name.is_empty():
		return
		
	# Check if name already exists (case-insensitive)
	for group in scene_groups:
		if group.name.to_lower() == new_name.to_lower():
			print("Group with name '%s' already exists!" % new_name)
			# FIX: Use push_error for editor console feedback
			push_error("Group with name '%s' already exists (case-insensitive check)." % new_name)
			return

	# Determine the new index (always the highest number + 1)
	var new_index = 0
	if not scene_groups.is_empty():
		var max_index = -1
		for group in scene_groups:
			if group.index > max_index:
				max_index = group.index
		new_index = max_index + 1
	
	scene_groups.append({
		"name": new_name,
		"index": new_index,
		"scenes": []
	})
	
	add_group_line_edit.clear()
	_save_groups() # Save and update UI

func _on_remove_group_pressed(group_array_index): 
	# Remove the group by its array index
	scene_groups.remove_at(group_array_index) 
	_save_groups() # Save and update UI

func _on_assign_scene_pressed(group_array_index): 
	var interface = get_editor_interface()
	var selection = interface.get_selection()
	var selected_nodes = selection.get_selected_nodes()
	
	if selected_nodes.is_empty():
		# FIX: Use push_error for editor console feedback
		push_error("Please select a Node in the Scene Tree whose root is the scene you want to assign.")
		return
	
	# We only process the first selected node
	var selected_node = selected_nodes[0]
	var scene_path = selected_node.scene_file_path # Get the path of the scene this node belongs to
	
	if scene_path.is_empty():
		# If the node is not part of a saved scene, try getting the current edited scene path
		var current_scene = interface.get_edited_scene_root()
		if current_scene:
			scene_path = current_scene.scene_file_path
		
		if scene_path.is_empty():
			# FIX: Use push_error for editor console feedback
			push_error("The selected node is not part of a saved scene file.")
			return
			
	# Fetch the group object
	var group = scene_groups[group_array_index] 
	
	if group.scenes.has(scene_path):
		# Remove if already exists (toggle behavior)
		group.scenes.erase(scene_path)
		print("Scene '%s' removed from group [%d] %s" % [scene_path, group.index, group.name])
		interface.set_main_screen_editor("2D") # Focus hack to clear errors
	else:
		# Add the scene path
		group.scenes.append(scene_path)
		print("Scene '%s' assigned to group [%d] %s" % [scene_path, group.index, group.name])

	_save_groups() # Save and update UI
