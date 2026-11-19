import QtQuick

// Stands in for qs.Ui's KeyboardPanel in the test harness. The real one is a
// layer-shell window that needs a Wayland compositor; the widget's logic does
// not, so its content gets a plain Item with the same properties and helpers.
Item {
  id: root
  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property bool open: false
  property Item focusTarget: null
  property int contentWidth: 280
  property int contentHeight: 200
  width: contentWidth
  height: contentHeight
  default property alias contentItem: holder.children

  function fittedContentWidth(width, cap) {
    var desired = Math.max(1, Number(width) || 1)
    return Math.round(cap !== undefined && Number(cap) > 0 ? Math.min(desired, Number(cap)) : desired)
  }
  function fittedContentHeight(implicitHeight, cap) {
    var desired = Math.max(1, Number(implicitHeight) || 1)
    return Math.round(cap !== undefined && Number(cap) > 0 ? Math.min(desired, Number(cap)) : desired)
  }

  Item { id: holder; anchors.fill: parent }
}
