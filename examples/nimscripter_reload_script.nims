proc setup*() =
  echo "hello from nimscript!"

proc update*() =
  discard

proc draw*() =
  text("this is drawn from script!", 30, 30)

  color(randf(), randf(), randf())
  drawAt(mouseX(), mouseY(), 30)