import Toybox.Activity;
import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

// ─── Layout (454×454 Descent Mk3i 51mm) ──────────────────────────────────────
//  Fully symmetric around center y=227. Top mirrors bottom exactly.
//
//  y=48   [          MON 1          ]  ← date, FONT_MEDIUM, orange
//  y=74   ─────────────── (w=282) ──────────────
//         [ ☀ 53° ] | [  S 6  ] | [-59ft]   ← info row, y=95
//  ├── vlines x=161,293: y=82→132 ──────────────────────────┤
//  y=140  ▓▓▓▓▓ BATTERY (on 5-seg line) ▓▓▓▓▓ ← barY=137, BATT_H=6
//
//          [   21  :  00   ] [  0  ]  ← time center y=227
//                             [ :06 ]
//
//  y=314  ▒▒▒▒▒ 5-seg line (mirrors battery) ▒▒▒▒▒
//  ├── vlines x=161,293: y=322→372 ─────────────────────────┤
//         [ 🔋 52% ] | [ ⚡ 31 ] | [ 🔥 0 ]  ← data row, y=359
//  y=380  ─────────────── (w=282) ──────────────
//                   [ ♥  166  ]             ← HR bottom center, y=406
//
//  NFT arc drawn last — always on top of everything
//

const SCR_CX = 227;
const SCR_CY = 227;

const DATE_Y  = 48;     // symmetric with BOT_Y=406  (48+406=454)
const LINE1_Y = 74;     // symmetric with LINE5_Y=380 (74+380=454)
const INFO_Y  = 107;    // centered in cell [74,140]: (74+140)/2=107; symmetric with DATA_Y=347
const LINE3_Y = 140;    // battery bar ON this 5-segment line, top of time (140+314=454)
const TIME_Y  = 227;    // true screen center
const LINE4_Y = 314;    // 5-segment line, bottom of time (mirrors LINE3_Y)
const DATA_Y  = 347;    // centered in cell [314,380]: (314+380)/2=347; symmetric with INFO_Y=107
const LINE5_Y = 380;    // symmetric with LINE1_Y
const BOT_Y   = 406;    // symmetric with DATE_Y

const BATT_H  = 6;
const TIME_CX = 227;    // true screen center — digits fill the widest zone
const SEC_X   = 405;    // seconds + msg bubble — pushed to right edge of circle

// Info row — mirrors data row exactly (same D1/D2/D3 centers, same dividers)
const INFO_CELL1_CX = 95;
const INFO_CELL2_CX = 227;
const INFO_CELL3_CX = 359;

// Data row — 3 cells
const D1 = 95;
const D2 = 227;
const D3 = 359;

// ─── Colors ───────────────────────────────────────────────────────────────────
const C_BG      = 0x000000;
const C_WHITE   = 0xFFFFFF;
const C_ORANGE  = 0xFF8C00;
const C_YELLOW  = 0xFFDD00;
const C_DIM     = 0x777777;
const C_TRACK   = 0x1A0A00;

const C_BATT_HI  = 0xFF8C00;
const C_BATT_MID = 0xFFDD00;
const C_BATT_LOW = 0xFF2200;

const C_NFT_ARC = 0xFF0000;
const C_NFT_TRK = 0x2A0000;
const NFT_R     = 224;   // arc sits at screen edge (pen ±2 → outer rim at 226)
const NFT_PEN   = 4;

class WatchFaceView extends WatchUi.WatchFace {

    private var _hrId;
    private var _calId;
    private var _bbId;
    private var _stId;
    private var _nftId;

    private var _heartRate;
    private var _calories;
    private var _bodyBattery;
    private var _stress;
    private var _nftMinutes;
    private var _timeFont as Graphics.VectorFont?;

    function initialize() {
        WatchFace.initialize();
        if (Toybox has :Complications) {
            _hrId  = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE);
            _calId = new Complications.Id(Complications.COMPLICATION_TYPE_CALORIES);
            _bbId  = new Complications.Id(Complications.COMPLICATION_TYPE_BODY_BATTERY);
            _stId  = new Complications.Id(Complications.COMPLICATION_TYPE_STRESS);
            if (Complications has :COMPLICATION_TYPE_NO_FLY_TIME) {
                _nftId = new Complications.Id(Complications.COMPLICATION_TYPE_NO_FLY_TIME);
            }
        }
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _timeFont = null;
        if (!(Graphics has :getVectorFont)) { return; }
        // Face name is the Font ID from device profile, not the TTF family name.
        // "BionicBold" = FONT_NUMBER_HOT face (Bionic_Bold_Number_Only.ttf).
        // "RobotoCondensedBold" is the fallback for simulator/other devices.
        _timeFont = Graphics.getVectorFont(
            {:face => ["BionicBold", "RobotoCondensedBold"], :size => 210});
    }

    function onShow() as Void {
        if (!(Toybox has :Complications)) { return; }
        Complications.registerComplicationChangeCallback(method(:onComplicationChange));
        var ids = [_hrId, _calId, _bbId, _stId];
        for (var i = 0; i < ids.size(); i++) {
            if (ids[i] != null) { Complications.subscribeToUpdates(ids[i]); }
        }
        if (_nftId != null) { Complications.subscribeToUpdates(_nftId); }
    }

    function onHide() as Void {
        if (!(Toybox has :Complications)) { return; }
        var ids = [_hrId, _calId, _bbId, _stId, _nftId];
        for (var i = 0; i < ids.size(); i++) {
            if (ids[i] != null) { Complications.unsubscribeFromUpdates(ids[i]); }
        }
    }

    function onComplicationChange(id as Complications.Id) as Void {
        _refreshComplications();
        WatchUi.requestUpdate();
    }

    // ─── Main draw — NFT arc is last so it's always on top ───────────────────
    function onUpdate(dc as Graphics.Dc) as Void {
        _refreshComplications();
        dc.setColor(C_BG, C_BG);
        dc.clear();
        _drawDate(dc);
        _drawGrid(dc);
        _drawInfoRow(dc);
        _drawBatteryBar(dc);
        _drawTime(dc);
        _drawDataRow(dc);
        _drawBottomRow(dc);
        _drawNftArc(dc);
    }

    // ─── NFT outer arc ────────────────────────────────────────────────────────
    private function _drawNftArc(dc as Graphics.Dc) as Void {
        dc.setPenWidth(NFT_PEN);
        dc.setColor(C_NFT_TRK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(SCR_CX, SCR_CY, NFT_R);
        var hours = 0.0;
        if (_nftMinutes != null && _nftMinutes > 0) {
            hours = _nftMinutes / 60.0;
            if (hours > 24.0) { hours = 24.0; }
        } else {
            var t = System.getClockTime();
            hours = t.hour.toFloat() + t.min / 60.0;
        }
        if (hours > 0.0) {
            var sweep = (hours / 24.0 * 360.0).toNumber();
            dc.setColor(C_NFT_ARC, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(SCR_CX, SCR_CY, NFT_R, Graphics.ARC_CLOCKWISE, 90, 90 - sweep);
        }
        dc.setPenWidth(1);
    }

    // ─── Date ─────────────────────────────────────────────────────────────────
    private function _drawDate(dc as Graphics.Dc) as Void {
        var now  = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var days = ["SUN","MON","TUE","WED","THU","FRI","SAT"];
        var str  = days[now.day_of_week - 1] + " " + now.day.toString();
        dc.setColor(C_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SCR_CX, DATE_Y, Graphics.FONT_MEDIUM, str,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ─── Grid ─────────────────────────────────────────────────────────────────
    // Horizontal widths: 16px inset from arc (r_eff=208). Vertical: 8px inset.
    // Top mirrors bottom exactly around center y=227.
    private function _drawGrid(dc as Graphics.Dc) as Void {
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Outer dividers (top/bottom) — dist=153, r_eff=208, half≈141, w=282
        _hline(dc, LINE1_Y, 282);
        _hline(dc, LINE5_Y, 282);
        // 5-segment separators — battery bar sits on LINE3_Y; LINE4_Y mirrors it
        var segW   = 73;
        var gap    = 3;
        var startX = SCR_CX - (5 * segW + 4 * gap) / 2;
        for (var i = 0; i < 5; i++) {
            var sx = startX + i * (segW + gap);
            dc.drawLine(sx, LINE3_Y, sx + segW, LINE3_Y);
        }
        _hline(dc, LINE4_Y, 5 * segW + 4 * gap);
        // Info row dividers: shifted inward to x=175/279 (±52 from center) to give
        // outer cells room for wider FONT_SMALL text
        _vline(dc, 175, LINE1_Y + 8, LINE3_Y - 8);
        _vline(dc, 279, LINE1_Y + 8, LINE3_Y - 8);
        // Data row dividers: same x as info row
        _vline(dc, 175, LINE4_Y + 8, LINE5_Y - 8);
        _vline(dc, 279, LINE4_Y + 8, LINE5_Y - 8);
    }

    // ─── Info row ─────────────────────────────────────────────────────────────
    private function _drawInfoRow(dc as Graphics.Dc) as Void {
        var condition = -1;
        var tempStr   = "--";
        var windStr   = "--";
        var altStr    = "--";

        if (Toybox has :Weather) {
            var w = Weather.getCurrentConditions();
            if (w != null) {
                condition = w.condition != null ? w.condition : -1;
                if (w.temperature != null) {
                    var f = (w.temperature.toFloat() * 9.0 / 5.0 + 32.0).toNumber();
                    tempStr = f.toString() + "°";
                }
                if (w.windSpeed != null && w.windBearing != null) {
                    var kts = (w.windSpeed.toFloat() * 1.944).toNumber();
                    windStr = _compass(w.windBearing) + " " + kts.toString();
                }
            }
        }
        var act = Activity.getActivityInfo();
        if (act != null && act.altitude != null) {
            altStr = (act.altitude.toFloat() * 3.2808).toNumber().toString() + "ft";
        }

        var isNight = false;
        var hr = System.getClockTime().hour;
        if (hr < 6 || hr >= 20) { isNight = true; }

        var infoY = INFO_Y - 2;
        // Cell 1: 40px icon, text right of icon
        _drawWeatherIcon(dc, INFO_CELL1_CX - 12, infoY + 5, condition, isNight);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(INFO_CELL1_CX + 16, infoY, Graphics.FONT_TINY, tempStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Cell 2: text centered
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(INFO_CELL2_CX, infoY, Graphics.FONT_TINY, windStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Cell 3: text centered
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(INFO_CELL3_CX - 10, infoY, Graphics.FONT_TINY, altStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ─── Battery bar — 5 segments centered on LINE3_Y ────────────────────────
    // barY centers the 6px bar on LINE3_Y so it sits directly on the grid line.
    // Only filled segments are drawn; empty ones let the dim grid line show through.
    private function _drawBatteryBar(dc as Graphics.Dc) as Void {
        var batt   = System.getSystemStats().battery.toNumber();
        var col    = batt > 30 ? C_BATT_HI : (batt > 15 ? C_BATT_MID : C_BATT_LOW);
        var segW   = 73;
        var gap    = 3;
        var barY   = LINE3_Y - BATT_H / 2;   // center bar on LINE3_Y grid line
        var totalW = 5 * segW + 4 * gap;      // 377px
        var startX = SCR_CX - totalW / 2;

        for (var i = 0; i < 5; i++) {
            var segX   = startX + i * (segW + gap);
            var segMin = i * 20;
            var segMax = (i + 1) * 20;
            if (batt >= segMax) {
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(segX, barY, segW, BATT_H);
            } else if (batt > segMin) {
                var fillW = (batt - segMin) * segW / 20;
                if (fillW > 0) {
                    dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(segX, barY, fillW, BATT_H);
                }
            }
        }
    }

    // ─── Time: Bionic vector font at 170px (same style as FONT_NUMBER_HOT, larger) ──
    private function _drawTime(dc as Graphics.Dc) as Void {
        var t    = System.getClockTime();
        var h12  = t.hour % 12;
        if (h12 == 0) { h12 = 12; }
        var hStr = _pad(h12);
        var mStr = _pad(t.min);
        var ampm = t.hour < 12 ? "AM" : "PM";

        // Use vector font (Bionic 170px) when available, else fall back to FONT_NUMBER_HOT
        var timeFont = (_timeFont != null) ? _timeFont : Graphics.FONT_NUMBER_HOT;
        // Shift draw anchor below screen center: font line-height includes descent space
        // below number glyphs, so cap height visually sits above the VCENTER point.
        var timeY = TIME_Y + 7;

        // Colon uses FONT_NUMBER_HOT (~159px) — smaller than digit font, same Bionic style
        var colonFont = Graphics.FONT_NUMBER_HOT;

        var x  = 12;
        var hW = dc.getTextWidthInPixels(hStr, timeFont);
        var cW = dc.getTextWidthInPixels(":",  colonFont);

        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, timeY, timeFont, hStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += hW;
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, timeY - 10, colonFont, ":",
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += cW;
        dc.setColor(C_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, timeY, timeFont, mStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Right column: pin msg top to digit top, :SS bottom to digit bottom, ampm in middle
        var msgH  = 23;
        var ampmH = dc.getFontHeight(Graphics.FONT_TINY);
        var secH  = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var digitH   = dc.getFontHeight(timeFont);
        var digitTop = timeY - digitH / 2;
        var digitBot = timeY + digitH / 2;

        var msgCY  = digitTop + msgH / 2;
        var secCY  = digitBot - secH / 2;
        var ampmCY = (digitTop + msgH + digitBot - secH) / 2;

        var cfg   = System.getDeviceSettings();
        var notif = 0;
        if (cfg has :notificationCount) { notif = cfg.notificationCount; }
        _drawMsgBubble(dc, SEC_X - 7, msgCY + 48, notif);

        dc.setColor(C_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SEC_X - 1, ampmCY + 50, Graphics.FONT_TINY, ampm,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Seconds: small grey ":" + red digits, centered together at SEC_X+5
        var secStr  = _pad(t.sec);
        var sColW   = dc.getTextWidthInPixels(":", Graphics.FONT_SMALL);
        var sDigW   = dc.getTextWidthInPixels(secStr, Graphics.FONT_MEDIUM);
        var sStartX = SEC_X + 3 - (sColW + sDigW) / 2;
        var sY      = secCY - 85;
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sStartX, sY - 2, Graphics.FONT_SMALL, ":",
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(C_NFT_ARC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sStartX + sColW + 2, sY, Graphics.FONT_MEDIUM, secStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Speech bubble with notification count
    private function _drawMsgBubble(dc as Graphics.Dc, cx as Number, cy as Number,
                                     count as Number) as Void {
        var w = 35;
        var h = 23;
        var r = 5;
        dc.setColor(C_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - w/2, cy - h/2, w, h, r);
        dc.fillPolygon([[cx - w/2,     cy + h/2],
                        [cx - w/2 + 6, cy + h/2],
                        [cx - w/2,     cy + h/2 + 6]]);
        dc.setColor(C_BG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_XTINY,
                    (count > 99 ? "99" : count.toString()),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ─── Data row: Body Battery | Stress | Calories ───────────────────────────
    private function _drawDataRow(dc as Graphics.Dc) as Void {
        var dataY  = DATA_Y;
        var bbVal  = _bodyBattery != null ? (_bodyBattery > 99 ? 99 : _bodyBattery) : null;
        var bbStr  = bbVal != null ? bbVal.toString() + "%" : "--%";
        _drawBatteryIcon(dc, D1 - 17, dataY + 2);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(D1 + 6, dataY, Graphics.FONT_TINY, bbStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var stVal  = _stress != null ? (_stress > 99 ? 99 : _stress) : null;
        var stStr  = stVal != null ? stVal.toString() : "--";
        _drawCrosshair(dc, D2 - 24, dataY + 2);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(D2 + 4, dataY, Graphics.FONT_TINY, stStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var calStr = _calories != null ? _calories.toString() : "--";
        _drawCaloriesIcon(dc, D3 - 57, dataY + 2);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(D3 - 39, dataY, Graphics.FONT_TINY, calStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ─── Bottom row: mirrors date row — icon + orange FONT_MEDIUM, centered ───
    private function _drawBottomRow(dc as Graphics.Dc) as Void {
        var hrStr = _heartRate != null ? _heartRate.toString() : "--";
        // Center icon+value group at SCR_CX (mirrors date centering)
        var icx = SCR_CX - 38;
        var bmp = Application.loadResource(Rez.Drawables.IconHeartRate) as WatchUi.BitmapResource;
        if (bmp != null) {
            dc.drawBitmap(icx - 27, BOT_Y - 26, bmp);  // 54px icon centered at (icx, BOT_Y+1)
        } else {
            _drawHeart(dc, icx, BOT_Y);
        }
        dc.setColor(C_NFT_ARC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(icx + 26, BOT_Y, Graphics.FONT_MEDIUM, hrStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ─── Weather icons (PNG bitmaps from mikeller/garmin-divesite-weather-widget)
    private function _drawWeatherIcon(dc as Graphics.Dc, cx as Number, cy as Number,
                                      condition as Number, isNight as Boolean) as Void {
        var rezId;
        if (condition == 0 || condition == 21 || condition == -1) {
            rezId = isNight ? Rez.Drawables.WxClearNight : Rez.Drawables.WxClearDay;
        } else if (condition == 1 || condition == 5) {
            rezId = isNight ? Rez.Drawables.WxPartlyCloudyNight : Rez.Drawables.WxPartlyCloudyDay;
        } else if (condition == 2 || condition == 20) {
            rezId = Rez.Drawables.WxCloudy;
        } else if (condition == 3 || condition == 7 || condition == 10 ||
                   condition == 11 || condition == 13 || condition == 14 || condition == 15 ||
                   condition == 18 || condition == 19) {
            rezId = Rez.Drawables.WxRain;
        } else if (condition == 4 || condition == 16 || condition == 17) {
            rezId = Rez.Drawables.WxSnow;
        } else if (condition == 6 || condition == 12) {
            rezId = Rez.Drawables.WxRainThunder;
        } else if (condition == 8 || condition == 9) {
            rezId = Rez.Drawables.WxFog;
        } else {
            rezId = isNight ? Rez.Drawables.WxClearNight : Rez.Drawables.WxClearDay;
        }
        var bmp = Application.loadResource(rezId) as WatchUi.BitmapResource;
        if (bmp != null) {
            dc.drawBitmap(cx - 20, cy - 20, bmp);
        }
    }

    // ─── Data icons ───────────────────────────────────────────────────────────

    // Body battery icon (33px icons8 PNG bitmap)
    private function _drawBatteryIcon(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
        var bmp = Application.loadResource(Rez.Drawables.IconBodyBattery) as WatchUi.BitmapResource;
        if (bmp != null) {
            dc.drawBitmap(cx - 16, cy - 16, bmp);
        }
    }

    // Stress icon (33px icons8 PNG bitmap)
    private function _drawCrosshair(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
        var bmp = Application.loadResource(Rez.Drawables.IconStress) as WatchUi.BitmapResource;
        if (bmp != null) {
            dc.drawBitmap(cx - 16, cy - 16, bmp);
        }
    }

    // Calories icon (33px icons8 PNG bitmap)
    private function _drawCaloriesIcon(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
        var bmp = Application.loadResource(Rez.Drawables.IconCalories) as WatchUi.BitmapResource;
        if (bmp != null) {
            dc.drawBitmap(cx - 16, cy - 16, bmp);
        }
    }

    private function _drawHeart(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
        dc.setColor(C_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx-5, cy-3, 6);
        dc.fillCircle(cx+5, cy-3, 6);
        dc.fillPolygon([[cx-10, cy+2], [cx, cy+11], [cx+10, cy+2],
                        [cx+5,  cy-5], [cx-5, cy-5]]);
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    private function _refreshComplications() as Void {
        if (!(Toybox has :Complications)) { return; }
        _heartRate   = _cv(_hrId);
        _calories    = _cv(_calId);
        _bodyBattery = _cv(_bbId);
        _stress      = _cv(_stId);
        if (_nftId != null) { _nftMinutes = _cv(_nftId); }
    }

    private function _cv(id) {
        if (id == null) { return null; }
        var c = Complications.getComplication(id);
        return c != null ? c.value : null;
    }

    private function _pad(n as Number) as String {
        return n < 10 ? "0" + n.toString() : n.toString();
    }

    private function _compass(deg as Number) as String {
        var d = ["N","NE","E","SE","S","SW","W","NW"];
        return d[((deg.toFloat() + 22.5) / 45.0).toNumber() % 8];
    }

    private function _hline(dc as Graphics.Dc, y as Number, w as Number) as Void {
        dc.drawLine(SCR_CX - w / 2, y, SCR_CX + w / 2, y);
    }

    private function _vline(dc as Graphics.Dc, x as Number, y1 as Number, y2 as Number) as Void {
        dc.drawLine(x, y1, x, y2);
    }
}
