@tool
extends EditorImportPlugin

enum Presets { DEFAULT }


func _get_importer_name():
	return "dt.abfi"

func _get_visible_name():
	return "Font data (Allegro)"

func _get_recognized_extensions():
	return ["png"]

func _get_save_extension():
	return "fontdata"

func _get_resource_type():
	return "FontFile"

func _get_preset_count():
	return Presets.size()

func _get_preset_name(preset):
	match preset:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"

func _get_import_options(_path, preset):
	var options := [
		{
			name = "ranges",
			default_value = PackedStringArray(["", ""]),
		},
		{
			name = "letter_spacing",
			default_value = 0,
		},
		{
			name = "mipmaps",
			default_value = false,
		},
	]

	match preset:
		Presets.DEFAULT:
			return options
		_:
			return []

func _get_option_visibility(_path, _option, _options):
	return true

func _get_import_order() -> int:
	return 0


func _import(source_file, save_path, options, _platform_variants, _gen_files):
	# --- validate ranges ---
	var ranges := (options.ranges as PackedStringArray)
	var ranges_n2 = ranges.size()

	if ranges_n2 == 0:
		push_error("'ranges' must have elements")
	if ranges_n2 % 2 != 0:
		push_error("Size of 'ranges' must be a multiple of two")
		return ERR_PARSE_ERROR

	for i in range(ranges_n2):
		if ranges[i].length() != 1:
			push_error("Each element of 'ranges' must be a single character")
			return ERR_PARSE_ERROR
		# every other string must have a codepoint less than its predecessor
		if (i % 2) and (ranges[i] < ranges[i-1]):
			push_error("Every other element of 'ranges' must be higher than its predecessor ('%s' vs '%s')" % [ranges[i-1], ranges[i]])
			return ERR_PARSE_ERROR

	# --- make list of glyphs ---
	var ranges_n = ranges_n2 / 2
	var glyphs := PackedInt64Array([])

	for i in range(ranges_n):
		var i_from := i*2
		var i_to   := i_from + 1
		var from := ranges[i_from].unicode_at(0)
		var to   := ranges[i_to].unicode_at(0)

		var j := from
		while j <= to:
			glyphs.push_back(j)
			j += 1

	var glyphs_n := glyphs.size()

	# --- load source file ---
	var file := FileAccess.open(source_file, FileAccess.READ)
	var err := file.get_open_error()
	if err:
		push_error("Couldn't open source file")
		return err

	var image := Image.new()
	err = image.load_png_from_buffer(file.get_buffer(file.get_length()))
	file = null
	if err:
		push_error("Couldn't decode source file")
		return err

	# --- iterate over source file's pixels ---
	var image_w := image.get_width()
	var image_h := image.get_height()
	var delimiter: Color
	var font_h := 0

	# the top-left corner defines the delimiter color
	delimiter = image.get_pixel(0, 0)

	# figure out the font height - start by finding the first glyph
	for x in range(1, image_w):
		if image.get_pixel(x, 1) == delimiter:
			continue

		# ...then how far down we can go before finding the delimiter color
		for y in range(1, image_h):
			if image.get_pixel(x, y) == delimiter:
				font_h = y - 1
				break
		if font_h == 0:
			push_error("The first glyph is a longboi (couldn't ascertain height)")
			return ERR_FILE_CORRUPT
		break

	if font_h == 0:
		push_error("Couldn't find the first glyph")
		return ERR_FILE_CORRUPT

	var in_glyph := false
	var glyph_i := 0
	var glyph_lines := []
	var glyph_line := []
	var glyph_surplus := false

	for y in range(image_h):
		var delimiter_line := false
		var top_line := false

		for x in range(image_w):
			var color := image.get_pixel(x, y)

			# set all delimiter color pixels to transparent as we iterate. the
			# delimiter color bleeds through into the text when it is transformed
			# otherwise (see #1)
			if color == delimiter:
				image.set_pixel(x, y, Color.TRANSPARENT)

			if delimiter_line:
				# if we run into something that isn't the delimiter color on a
				# separator line, the image isn't formatted correctly
				if color != delimiter:
					push_error("Pixel on seperator line isn't delimiter color (%s, %s)" % [x, y])
					return ERR_FILE_CORRUPT
				continue

			if x == 0:
				# is this a separator line?
				var y_in_row := y % (font_h + 1)
				if y_in_row == 0:
					delimiter_line = true
					if color != delimiter:
						push_error("Leftmost pixel isn't delimiter color (%s, %s)" % [x, y])
						return ERR_FILE_CORRUPT
				elif y_in_row == 1:
					top_line = true
				continue

			if (x == image_w - 1) and (color != delimiter):
				push_error("Rightmost pixel isn't delimiter color (%s, %s)" % [x, y])
				return ERR_FILE_CORRUPT
				# note that there's no 'continue' here, as the 'color == delimiter'
				# condition below might be needed to cap off a glpyh

			# if this is the top line of a row, we need to glyph positions in
			# the row
			if top_line:
				# check whether to add a glyph
				if not in_glyph:
					if color != delimiter:
						# if we've got all specified glyphs, pass over any surplus
						if glyph_i == glyphs_n:
							glyph_surplus = true
							continue

						in_glyph = true
						glyph_line.push_back([x, null])

				# check whether to cap off a glyph
				elif color == delimiter:
					# end glyph
					glyph_line.back()[1] = x
					in_glyph = false
					glyph_i += 1

			else:
				# TODO: for absolute pedantry, we should at this point check
				# there are no delimiter pixels within the glyphs on the
				# following lines. for now, this is probably fine though.
				pass

		if delimiter_line and (y != 0):
			glyph_lines.push_back(glyph_line)
			glyph_line = []

	if glyph_i != glyphs_n:
		push_warning("Missing glyphs from '%c' onwards" % glyphs[glyph_i])
	elif glyph_surplus:
		push_warning("There were more glyphs than specified in 'ranges' (expected %s)" % glyphs_n)

	# --- assemble BitmapFont ---
	var font := FontFile.new()

	var spacing := options.letter_spacing as int

	var size := Vector2i(font_h, 0)
	font.set_texture_image(0, size, 0, image)
	font.fixed_size = font_h
	font.allow_system_fallback = false
	font.generate_mipmaps = options.mipmaps
	font.set_cache_descent(0, size.x, font_h)

	glyph_i = 0
	for i in range(glyph_lines.size()):
		var y := 1 + (i * (font_h + 1))

		for x in glyph_lines[i]:
			var rect := Rect2(x[0], y, x[1] - x[0], font_h)
			var advance := rect.size.x + spacing
			var glyph = glyphs[glyph_i]
			font.set_glyph_uv_rect(0, size, glyph, rect)
			font.set_glyph_advance(0, size.x, glyph, Vector2(advance, 0))
			font.set_glyph_texture_idx(0, size, glyph, 0)
			font.set_glyph_offset(0, size, glyph, Vector2.ZERO)
			font.set_glyph_size(0, size, glyph, rect.size)

			glyph_i += 1

	# --- sorted mate ---
	return ResourceSaver.save(font, "%s.%s" % [save_path, _get_save_extension()])
