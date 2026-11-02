// DMOS default layout: a slim floating top bar and a centred floating dock.
var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
}

// DMOS Hub (clock, greeting and news) on the right of the first screen's desktop.
if (desktopsArray.length > 0) {
    var desk = desktopsArray[0];
    var geo = screenGeometry(desk.screen);
    var hubWidth = 400;
    var hubHeight = Math.min(660, geo.height - 200);
    var hubX = geo.width - hubWidth - 48;
    var hubY = 88;
    var hub = desk.addWidget("org.dmos.hub", hubX, hubY, hubWidth, hubHeight);
    // The folder view keeps applet positions in these keys and ignores addWidget's
    // geometry on the next start, which would move the hub to the top-left corner.
    var placement = "Applet-" + hub.id + ":" + hubX + "," + hubY + "," + hubWidth + "," + hubHeight + ",0;";
    desk.currentConfigGroup = [];
    desk.writeConfig("ItemGeometries-" + geo.width + "x" + geo.height, placement);
    desk.writeConfig("ItemGeometriesHorizontal", placement);
}

var bar = new Panel;
bar.location = "top";
bar.height = 38;
bar.floating = true;

var launcher = bar.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "dmos-logo");
// With the flag off, Kickoff imports this list into its favourites on first start.
launcher.writeConfig("favoritesPortedToKAstats", "false");
launcher.writeConfig("favorites", "firefox-esr.desktop,org.kde.dolphin.desktop,org.kde.konsole.desktop,libreoffice-writer.desktop,org.kde.discover.desktop,systemsettings.desktop");

bar.addWidget("org.kde.plasma.pager");
bar.addWidget("org.kde.plasma.panelspacer");

var clock = bar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");
clock.writeConfig("autoFontAndSize", "false");
clock.writeConfig("fontFamily", "Inter");
clock.writeConfig("fontWeight", "500");
clock.writeConfig("fontSize", "11");

bar.addWidget("org.kde.plasma.panelspacer");
bar.addWidget("org.kde.plasma.systemtray");
bar.addWidget("org.kde.plasma.showdesktop");

var dock = new Panel;
dock.location = "bottom";
dock.height = 66;
dock.floating = true;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.hiding = "dodgewindows";

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", "applications:firefox-esr.desktop,applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:org.kde.kate.desktop,applications:org.kde.gwenview.desktop,applications:org.kde.elisa.desktop,applications:libreoffice-writer.desktop,applications:org.kde.discover.desktop,applications:systemsettings.desktop");
tasks.writeConfig("iconSpacing", "2");
tasks.writeConfig("fill", "false");
tasks.writeConfig("maxStripes", "1");
