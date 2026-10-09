extends RefCounted
## Makes the text under a node copyable: rich text can be selected with the mouse and
## copied with Ctrl+C; a right click on a plain label copies the whole label.

static func apply(root: Node, copied := Callable()) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		if node is RichTextLabel:
			node.selection_enabled = true
			node.context_menu_enabled = true
		elif node is Label:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
			node.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not node.text.is_empty():
					DisplayServer.clipboard_set(node.text)
					if copied.is_valid():
						copied.call())
