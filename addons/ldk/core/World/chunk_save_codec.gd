extends RefCounted
## Encodes only overridden cells. Palette slot zero is the procedural baseline.

const DENSE_CHECK_COUNT := 256
const SPARSE_STRIDE := 4


static func encode(edits: Dictionary) -> Dictionary:
	var palette := PackedStringArray()
	var indices: Dictionary[StringName, int] = {}
	var sparse := PackedByteArray()
	sparse.resize(edits.size() * SPARSE_STRIDE)
	var offset := 0
	var cells := edits.keys()
	cells.sort()
	for cell: int in cells:
		var key: StringName = edits[cell]
		var index := indices.get(key, 0)
		if index == 0:
			palette.append(key)
			index = palette.size()
			indices[key] = index
		sparse.encode_u16(offset, cell)
		sparse.encode_u16(offset + 2, index)
		offset += SPARSE_STRIDE
	if edits.size() >= DENSE_CHECK_COUNT:
		var dense := _dense_buffer(sparse, palette.size())
		var compressed := dense.compress(FileAccess.COMPRESSION_ZSTD)
		if not compressed.is_empty() and compressed.size() < sparse.size():
			return {"palette": palette, "dense": true, "cells": compressed}
	return {"palette": palette, "dense": false, "cells": sparse}


static func decode(record: Variant) -> Variant:
	if not record is Dictionary or not record.get("palette") is PackedStringArray \
		or not record.get("dense") is bool or not record.get("cells") is PackedByteArray:
		return null
	var palette: PackedStringArray = record.palette
	var cells: PackedByteArray = record.cells
	if palette.size() > VoxelChunkData.VOLUME:
		return null
	var keys: Array[StringName] = [&""]
	for key in palette:
		if ContentRegistry.namespace_of(StringName(key)).is_empty():
			return null
		keys.append(ContentRegistry.normalize_id(StringName(key)))

	var edits: Dictionary[int, StringName] = {}
	if record.dense:
		var stride := 1 if palette.size() < 256 else 2
		var length := VoxelChunkData.VOLUME * stride
		cells = cells.decompress(length, FileAccess.COMPRESSION_ZSTD)
		if cells.size() != length:
			return null
		for cell in VoxelChunkData.VOLUME:
			var index := cells[cell] if stride == 1 else cells.decode_u16(cell * stride)
			if index >= keys.size():
				return null
			if index != 0:
				edits[cell] = keys[index]
	else:
		if cells.size() > VoxelChunkData.VOLUME * SPARSE_STRIDE or cells.size() % SPARSE_STRIDE != 0:
			return null
		for offset in range(0, cells.size(), SPARSE_STRIDE):
			var cell := cells.decode_u16(offset)
			var index := cells.decode_u16(offset + 2)
			if cell >= VoxelChunkData.VOLUME or index <= 0 or index >= keys.size() or edits.has(cell):
				return null
			edits[cell] = keys[index]
	return edits


static func _dense_buffer(sparse: PackedByteArray, palette_size: int) -> PackedByteArray:
	var stride := 1 if palette_size < 256 else 2
	var dense := PackedByteArray()
	dense.resize(VoxelChunkData.VOLUME * stride)
	for offset in range(0, sparse.size(), SPARSE_STRIDE):
		var cell := sparse.decode_u16(offset)
		var index := sparse.decode_u16(offset + 2)
		if stride == 1:
			dense[cell] = index
		else:
			dense.encode_u16(cell * stride, index)
	return dense
