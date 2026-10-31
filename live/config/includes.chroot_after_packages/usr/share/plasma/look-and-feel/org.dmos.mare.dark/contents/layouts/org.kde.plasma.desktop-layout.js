// DMOS default layout: a slim floating top bar and a centred floating dock.
var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
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
