TimesMap(f, n)
{
  result := []
  Loop, % n
  {
    result.Push(f.Call(A_Index))
  }
  return result
}

ArrayForEach(f, a)
{
  for index, value in a
  {
    f.Call(value, index, a)
  }
}

ArrayMap(f, a)
{
  result := []
  for index, value in a
  {
    result.Push(f.Call(value, index, a))
  }
  return result
}

ArrayFilter(f, a)
{
  result := []
  for index, value in a
  {
    if (f.Call(value, index, a))
    {
      result.Push(value)
    }
  }
  return result
}

ArrayFlatMap(f, a)
{
  result := []
  for index, value in a
  {
    intermediateResult := f.Call(value, index, a)
    for _, v in intermediateResult
    {
      result.Push(v)
    }
  }
  return result
}

Flipped(f, b, a, n*)
{
  return f.Call(a, b, n*)
}

Flip(f, n*)
{
  return Func("Flipped").Bind(f, n*)
}

GetMonitorRegion(monitorNumber)
{
  SysGet, monitor, MonitorWorkArea, % monitorNumber
  return {x: monitorLeft, y: monitorTop, width: monitorRight - monitorLeft, height: monitorBottom - monitorTop, name: "Monitor " . monitorNumber}
}

GetMonitorRegions()
{
  SysGet, monitorCount, MonitorCount
  return TimesMap(Func("GetMonitorRegion"), monitorCount)
}

GetWindowIds()
{
  windowIds := []
  WinGet, windows, List
  Loop, % windows
  {
    windowIds.Push(windows%A_Index%)
  }
  return windowIds
}

GetWindowRegion(windowId)
{
  WinGetPos, x, y, w, h, % "ahk_id " windowId
  WinGetTitle, title, % "ahk_id " windowId
  return {x: x, y: y, width: w, height: h, name: title}
}

IsNotInIgnoreSet(ignoreSet, windowRegion)
{
  return not ignoreSet.HasKey(windowRegion.name)
}

GetWindowRegions(ignoreSet)
{
  return ArrayFilter(Func("IsNotInIgnoreSet").Bind(ignoreSet), ArrayMap(Func("GetWindowRegion"), GetWindowIds()))
}

RectangleBounds(rectangle)
{
  return {left: rectangle.x, right: rectangle.x + rectangle.width, top: rectangle.y, bottom: rectangle.y + rectangle.height}
}

RectangularBoundsOverlap(a, b)
{
  return Max(a.right - 1, b.right - 1) - Min(a.left, b.left) <= (a.right - a.left - 1) + (b.right - b.left - 1) and Max(a.bottom - 1, b.bottom - 1) - Min(a.top, b.top) <= (a.bottom - a.top - 1) + (b.bottom - b.top - 1)
}

CutRectangle(rectangle, cutter)
{
  areaBounds := RectangleBounds(rectangle)
  cutterBounds := RectangleBounds(cutter)

  ; Check if there's any overlap at all first; if not, just return the original rectangle.
  if (not RectangularBoundsOverlap(areaBounds, cutterBounds))
  {
    ; MsgBox, % "No overlap detected: (" areaBounds.left ", " areaBounds.top ", " areaBounds.right ", " areaBounds.bottom ") (" cutterBounds.left ", " cutterBounds.top ", " cutterBounds.right ", " cutterBounds.bottom ")"
    return [rectangle]
  }

  remains := []
  ; If the left side of the cutter is in the area, then add a rectangle for the area left of the cutter but within the rectangle
  if (areaBounds.left < cutterBounds.left and cutterBounds.left < areaBounds.right)
  {
    remains.Push({x: rectangle.x, y: rectangle.y, width: cutter.x - rectangle.x, height: rectangle.height})
  }
  ; If the right side of the cutter is in the area, then add a rectangle for the area right of the cutter but within the rectangle
  if (areaBounds.left < cutterBounds.right and cutterBounds.right < areaBounds.right)
  {
    remains.Push({x: cutterBounds.right, y: rectangle.y, width: areaBounds.right - cutterBounds.right, height: rectangle.height})
  }
  ; If the top of the cutter is in the area, then add a rectangle for the space above the cutter but all the way across the rectangle
  if (areaBounds.top < cutterBounds.top and cutterBounds.top < areaBounds.bottom)
  {
    remains.Push({x: rectangle.x, y: rectangle.y, width: rectangle.width, height: cutterBounds.top - rectangle.y})
  }
  ; If the bottom of the cutter is in the area, then add a rectangle for the space below the cutter but all the way across the rectangle
  if (areaBounds.top < cutterBounds.bottom and cutterBounds.bottom < areaBounds.bottom)
  {
    remains.Push({x: rectangle.x, y: cutterBounds.bottom, width: rectangle.width, height: areaBounds.bottom - cutterBounds.bottom})
  }
  return remains
}

FindUncoveredRegionsInRegion(region, covers)
{
  uncoveredRegions := [region]
  for i, cover in covers
  {
    uncoveredRegions := ArrayFlatMap(Flip(Func("CutRectangle"), cover), uncoveredRegions)
  }
  return uncoveredRegions
}

FindUncoveredRegions(initialRegions, covers)
{
  return ArrayFlatMap(Flip(Func("FindUncoveredRegionsInRegion"), covers), initialRegions)
}

RectangleContainsPoint(rectangle, point)
{
  return rectangle.x <= point.x and point.x < rectangle.x + rectangle.width and rectangle.y <= point.y and point.y < rectangle.y + rectangle.height
}

RectangleContainsRectangle(container, containee)
{
  left := containee.x
  right := containee.x + containee.width - 1
  top := containee.y
  bottom := containee.y + containee.height - 1
  return RectangleContainsPoint(container, containee) and RectangleContainsPoint(container, {x: left, y: bottom}) and RectangleContainsPoint(container, {x: right, y: top}) and RectangleContainsPoint(container, {x: right, y: bottom})
}

RemoveSelfIfFullyContained(rectangle, i, rectangles)
{
  for j, potentialContainer in rectangles
  {
    if (i != j and RectangleContainsRectangle(potentialContainer, rectangle))
    {
      return []
    }
  }
  return [rectangle]
}

ConsolidateRegions(regions)
{
  return ArrayFlatMap(Func("RemoveSelfIfFullyContained"), regions)
}

Main()
{
  monitors := GetMonitorRegions()
  windows := GetWindowRegions({"Program Manager": True, "NVIDIA GeForce Overlay": True})
  uncovered := ConsolidateRegions(FindUncoveredRegions(monitors, windows))

  MsgBox, % uncovered.Length() " remaining"
  Gui, Available:New, -Caption
  For index, rect in uncovered
  {
    bounds := RectangleBounds(rect)
    Gui, Show, % "x" rect.x " y" rect.y " w" rect.width " h" rect.height, Uncovered
    MsgBox % index ": (" bounds.left ", " bounds.bottom ", " bounds.right ", " bounds.top ")"
  }

  Gui, Destroy
  ExitApp
}

Main()