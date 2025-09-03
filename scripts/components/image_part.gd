extends PanelContainer


func set_image(img_texture: Texture2D):
	get_node("HBox/Thumb").texture = img_texture;
