extends Object
class_name DungeonGenerator


static func generate_dungeon(width: int, height: int) -> Array:
	var rows := []
	rows.resize(height)
	for i in height:
		rows[i] = []
		rows[i].resize(width)
		rows[i].fill(true)

	var paths: Array = []
	var root_node := Branch.new(Vector2i(0, 0), Vector2i(width, height))
	root_node.split(4, paths)

	for leaf in root_node.get_leaves():
		var padding = Vector4i(rand_pad(), rand_pad(), rand_pad(), rand_pad())
		for x in range(leaf.size.x):
			for y in range(leaf.size.y):
				if not is_inside_padding(x,y, leaf, padding) :
					rows[y + leaf.position.y][x + leaf.position.x] = false
	for path in paths:
		if path['left'].y == path['right'].y:
			for i in range(path['right'].x - path['left'].x):
				rows[path['left'].y][path['left'].x+i] = false
		else:
			for i in range(path['right'].y - path['left'].y):
				rows[path['left'].y+i][path['left'].x] = false

	for x in width:
		rows[0][x] = true
		rows[height - 1][x] = true
	for y in height:
		rows[y][width - 1] = true
		rows[y][0] = true

	return rows


static func is_inside_padding(x, y, leaf, padding):
	return (
		x <= padding.x
		or y <= padding.y
		or x >= leaf.size.x - padding.z
		or y >= leaf.size.y - padding.w
	)


static func rand_pad() -> int:
	var r := randf()
	if r < 0.1:
		return -1
	if r < 0.9:
		return 0
	return 1
