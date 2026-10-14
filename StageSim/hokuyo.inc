define hokuyo_sensor sensor
(
  range [ 0.0 4.0 ]
  fov 240.0
  samples 768
  color_rgba [ 0 0 1 0.15 ]
)

define hokuyo_laser ranger
(
  color "blue"
  size [ 0.05 0.05 0.1 ]
  hokuyo_sensor()
)
