import QtQuick

Canvas {
    id: icon

    required property string glyph
    property real level: 1
    property bool charging: false
    property bool muted: false
    property color ink: "#f5f7fb"

    implicitWidth: glyph === "battery" ? 21 : 17
    implicitHeight: 17

    onGlyphChanged: requestPaint()
    onLevelChanged: requestPaint()
    onChargingChanged: requestPaint()
    onMutedChanged: requestPaint()
    onInkChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        ctx.translate((width - 17) / 2, (height - 17) / 2);
        ctx.strokeStyle = ink;
        ctx.fillStyle = ink;
        ctx.lineWidth = 1.35;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        function line(points, closed = false) {
            ctx.beginPath();
            ctx.moveTo(points[0][0], points[0][1]);
            for (let i = 1; i < points.length; i++)
                ctx.lineTo(points[i][0], points[i][1]);
            if (closed) ctx.closePath();
            ctx.stroke();
        }

        function dot(x, y, radius) {
            ctx.beginPath();
            ctx.arc(x, y, radius, 0, 2 * Math.PI);
            ctx.fill();
        }

        function pill(x, y, w, h, filled = false) {
            ctx.beginPath();
            const radius = Math.min(2, w / 2, h / 2);
            ctx.roundedRect(x, y, w, h, radius, radius);
            if (filled) ctx.fill();
            else ctx.stroke();
        }

        switch (glyph) {
        case "wifi":
            for (let band = 0; band < 3; band++) {
                ctx.globalAlpha = level > band / 3 ? 1 : 0.33;
                ctx.beginPath();
                ctx.arc(8.5, 12.8, 3.5 + 3 * band, -2.32, -0.82);
                ctx.stroke();
            }
            ctx.globalAlpha = level > 0 ? 1 : 0.33;
            dot(8.5, 13.1, 0.95);
            break;
        case "sound":
            line([[1.6, 6.3], [4, 6.3], [7, 3.6], [7, 13.4], [4, 10.7], [1.6, 10.7]], true);
            if (muted) {
                line([[10.5, 6.8], [14.3, 10.6]]);
                line([[14.3, 6.8], [10.5, 10.6]]);
            } else {
                for (let wave = 0; wave < 3; wave++) {
                    ctx.globalAlpha = level > wave / 3 ? 1 : 0.25;
                    ctx.beginPath();
                    ctx.arc(7.7, 8.5, 2.7 + wave * 2.2, -0.77, 0.77);
                    ctx.stroke();
                }
            }
            break;
        case "battery":
            pill(-0.9, 4.35, 16.7, 8.3);
            ctx.globalAlpha = 0.55;
            pill(17, 7, 1.2, 3, true);
            ctx.globalAlpha = charging ? 0.32 : 1;
            if (level > 0) pill(0.8, 6, 13.3 * level, 5, true);
            if (charging) {
                ctx.globalAlpha = 1;
                line([[8.6, 5.6], [6.2, 8.8], [9.3, 8.8], [7, 11.5]]);
            }
            break;
        case "controls":
            pill(2.5, 2.5, 5, 5);
            dot(12, 5, 1.8);
            pill(2.5, 9.5, 5, 5);
            pill(9.5, 9.5, 5, 5);
            break;
        case "record":
            ctx.beginPath();
            ctx.arc(8.5, 8.5, 6.1, 0, 2 * Math.PI);
            ctx.stroke();
            dot(8.5, 8.5, 3.2);
            break;
        case "dnd":
            ctx.beginPath();
            ctx.moveTo(7.8, 2.4);
            ctx.bezierCurveTo(2.2, 2.6, 0.3, 9.4, 4.2, 13.2);
            ctx.bezierCurveTo(7.7, 16.5, 13.3, 14.9, 14.6, 10.5);
            ctx.bezierCurveTo(9.4, 12.2, 5.3, 7.5, 7.8, 2.4);
            ctx.fill();
            break;
        case "activity":
            pill(1.6, 3, 13.8, 11);
            line([[3.7, 8.7], [6, 8.7], [7.5, 5.9], [9.5, 11.3], [11.2, 8.7], [13.2, 8.7]]);
            break;
        case "hotspot":
            ctx.save();
            ctx.translate(8.5, 8.5);
            ctx.rotate(-Math.PI / 4);
            pill(-7.1, -2.55, 6, 5.1);
            pill(1.1, -2.55, 6, 5.1);
            line([[-2.7, 0], [2.7, 0]]);
            ctx.restore();
            break;
        }
    }
}
