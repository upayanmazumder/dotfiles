import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    forceWidth: true

    NoticeBox {
        Layout.fillWidth: true
        text: Translation.tr("Application window glass and shell glass are independent. Window presets change application windows only; the bar, dock, panels and widgets keep their own shell glass settings.")
    }

    LiquidGlassConfig {}

    LiquidGlassWindowsConfig {}
}
