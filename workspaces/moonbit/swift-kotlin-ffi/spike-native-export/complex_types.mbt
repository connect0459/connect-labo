#export_name("make_greeting")
pub fn make_greeting() -> String {
  "Hello from MoonBit!"
}

#export_name("string_length")
pub fn string_length(s : String) -> Int {
  s.length()
}

pub struct Point {
  x : Int
  y : Int
}

#export_name("make_point")
pub fn make_point(x : Int, y : Int) -> Point {
  { x, y }
}

#export_name("point_x")
pub fn point_x(p : Point) -> Int {
  p.x
}

#export_name("point_y")
pub fn point_y(p : Point) -> Int {
  p.y
}
