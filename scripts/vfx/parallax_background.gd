extends ParallaxBackground
## Infinite-feel parallax: Layer 1 distant stars, Layer 2 mid dust/nebula, Layer 3 slow color fog.
## No camera bounds; layers scroll with camera via ParallaxLayer motion_scale.

func _ready() -> void:
	# Ensure we're behind gameplay (z-index set on layers or parent)
	pass
