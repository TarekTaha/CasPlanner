define sick_sensor sensor
(
  range [ 0.0 8.0 ]
  fov 180.0
  samples 361
  color_rgba [ 0 0 1 0.15 ]
)

define sick_laser ranger
(
  color "blue"
  size [ 0.14 0.14 0.1 ]
  sick_sensor()
)
