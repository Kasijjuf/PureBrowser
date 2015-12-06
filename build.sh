#!/bin/sh
set -e
clear
basedir=$(echo $PWD)

DEBEMAIL=dev@puri.sm
DEBFULLNAME="PureOS GNU/Linux developers"

# get source and cd into it.
echo "Removing previous build files..."
rm -rf purebrowser*
echo
echo "Obtaining sources..." 
apt-src install iceweasel

find . -maxdepth 1 -type d -exec rename "s/iceweasel/purebrowser/" {} \;

cd purebrowser*

# remove the Iceweasel branding icon and logo and replace it.
echo "Replacing logo and icon."
rm -f debian/branding/iceweasel_icon.svg debian/branding/iceweasel_logo.svg
cp "$basedir"/data/purebrowser* debian/branding/

# Remove mozilla donation links in the about dialogue and some rebranding.
# TODO: Actually write a new aboutRights.xhtml
for STRING in rights.intro-point3-unbranded rights.intro-point4a-unbranded rights.intro-point4b-unbranded rights.intro-point4c-unbranded
do
    find -name aboutRights.dtd | xargs sed -i "s/ENTITY $STRING.*/ENTITY $STRING \"\">/"
done
		      
sed '/helpus.start/d' -i browser/base/content/aboutDialog.xul

cp "$basedir"/data/aboutRights.xhtml toolkit/content/aboutRights.xhtml
cp "$basedir"/data/aboutRights.xhtml toolkit/content/aboutRights-unbranded.xhtml
		        
sed -i 's/<a\ href\=\"http\:\/\/www.mozilla.org\/\">Mozilla\ Project<\/a>/<a\ href\=\"https\:\/\/puri.sm\/\"\>Purism<\/a>/g' browser/base/content/overrides/app-license.html

# stragglers
for file in $(grep "iceweasel" . -rl)
do
	sed 's/iceweasel/purebrowser/g' -i "$file"
	echo "Editing $file"
done

for file in $(grep "Iceweasel" . -rl)
do
	sed 's/Iceweasel/PureBrowser/g' -i "$file"
	echo "Editing $file"
done

for file in $(find . -type d|grep iceweasel)
do
	rename 's/iceweasel/purebrowser/' -i "$file"
	echo "Renaming $file"
done

for file in $(find . -type f|grep iceweasel)
do
	rename 's/iceweasel/purebrowser/' -i "$file"
	echo "Renaming $file"
done

for file in $(grep "ICEWEASEL" . -rl)
do
	sed 's/ICEWEASEL/PUREBROWSER/g' -i "$file"
	echo "Editing $file"
done

# js settings
cat "$basedir"/data/settings.js >> browser/app/profile/purebrowser.js

# install purebrowser extensions
cp "$basedir"/data/extensions/* debian/ -r

echo "Adding Privacy Badger."
echo "debian/jid1-MnnxcxisBPnSXQ-eff@jetpack usr/lib/purebrowser/browser/extensions/" >> debian/browser.install.in

echo "Adding https-everywhere."
echo "debian/https-everywhere-eff@eff.org usr/lib/purebrowser/browser/extensions/" >> debian/browser.install.in

echo "Adding html5-video-everywhere."
echo "debian/html5-video-everywhere@lejenome.me usr/lib/purebrowser/browser/extensions/" >> debian/browser.install.in

echo "Adding uBlock."
echo "debian/uBlock0@raymondhill.net usr/lib/purebrowser/browser/extensions/" >> debian/browser.install.in

# disable search field in extensions panel
echo "Disable search in extensions panel."
cat << EOF >> toolkit/mozapps/extensions/content/extensions.css
header-search {
  display:none;
}
EOF

# Postinst script to manage profile migration and system links
echo '

if [ "$1" = "configure" ] || [ "$1" = "abort-upgrade" ] ; then

[ -f /usr/bin/firefox ] || ln -s /usr/bin/purebrowser /usr/bin/firefox

for HOMEDIR in $(grep :/home/ /etc/passwd |grep -v usbmux |grep -v syslog|cut -d : -f 6)
do
    [ -d $HOMEDIR/.mozilla/purebrowser ] && continue || true
    [ -d $HOMEDIR/.mozilla/firefox ] || continue
    echo Linking $HOMEDIR/.mozilla/firefox into $HOMEDIR/.mozilla/purebrowser
    ln -s $HOMEDIR/.mozilla/firefox $HOMEDIR/.mozilla/purebrowser
done 
fi
exit 0 ' > debian/browser.postinst.in

#cat << EOF >> browser/app/Makefile.in
#libs::
#	cp -a \$(topsrcdir)/extensions/* \$(FINAL_TARGET)/extensions/
#	mkdir -p \$(DIST)/purebrowser/browser/extensions/ 
#	cp -a \$(topsrcdir)/extensions/* \$(DIST)/purebrowser/browser/extensions/
#EOF

#cat << EOF >> mobile/android/app/Makefile.in
#libs::
#	mkdir -p \$(DIST)/bin/distribution
#	cp -a \$(topsrcdir)/extensions/ \$(DIST)/bin/distribution/extensions
#EOF

#for EXTENSION in $(ls $basedir/data/extensions/); do
#	sed "/Browser Chrome Files/s%$%\n@BINPATH@/browser/extensions/$EXTENSION/*%" -i browser/installer/package-manifest.in mobile/android/installer/package-manifest.in
#done

# disconnect.me search engine as home page
sed -e "/startup.homepage_override/d" \
    -e "/startup.homepage_welcome/d" \
    -i debian/branding/firefox-branding.js

cat << EOF >> debian/branding/firefox-branding.js
lockPref("startup.homepage_override_url","https://duckduckgo.com");
lockPref("startup.homepage_welcome_url","https://duckduckgo.com");
EOF
export DEBEMAIL DEBFULLNAME && dch -p -l "-1" "Duckduckgo search page as home."

# Security Hardening
cat << EOF >>debian/vendor.js.in
// Disable Location-Aware Browsing
// http://www.mozilla.org/en-US/firefox/geolocation/
lockPref("geo.enabled",             false);
lockPref("browser.search.geoip.url",            "");

EOF
dch -a "Disable location-aware browsing."

cat << EOF >>debian/vendor.js.in
lockPref("media.peerconnection.enabled",            false);

EOF
dch -a "Disable media peer connections for internal IP leak."

cat << EOF >>debian/vendor.js.in
// https://developer.mozilla.org/en-US/docs/Web/API/BatteryManager
lockPref("dom.battery.enabled",             false);

EOF
dch -a "Disable battery monitor for internal IP leak."

cat << EOF >>debian/vendor.js.in
// https://wiki.mozilla.org/WebAPI/Security/WebTelephony
lockPref("dom.telephony.enabled",           false);

EOF
dch -a "Disable web telephony for internal IP leak."

cat << EOF >>debian/vendor.js.in
// https://developer.mozilla.org/en-US/docs/Web/API/navigator.sendBeacon
lockPref("beacon.enabled",          false);

EOF
dch -a "Disable navigator beacon for internal IP leak."

cat << EOF >>debian/vendor.js.in
// https://developer.mozilla.org/en-US/docs/Mozilla/lockPreferences/lockPreference_reference/dom.event.clipboardevents.enabled
lockPref("dom.event.clipboardevents.enabled",               false);

EOF
dch -a "Disable clipboard events for internal IP leak."

cat << EOF >>debian/vendor.js.in
// https://wiki.mozilla.org/HTML5_Speech_API
lockPref("media.webspeech.recognition.enable",              false);

EOF
dch -a "Disable speech recognition."

cat << EOF >>debian/vendor.js.in
// Disable getUserMedia screen sharing
// https://mozilla.github.io/webrtc-landing/gum_test.html
lockPref("media.getusermedia.screensharing.enabled",                false);

EOF
dch -a "Disable getUserMedia screen sharing."

cat << EOF >>debian/vendor.js.in
// Disable sensor API
// https://wiki.mozilla.org/Sensor_API
lockPref("device.sensors.enabled",          false);

EOF
dch -a "Disable sensor API."

cat << EOF >>debian/vendor.js.in
// Disable browser pings
// http://kb.mozillazine.org/Browser.send_pings
lockPref("browser.send_pings",              false);

// Disable health reporting
// https://support.mozilla.org/en-US/kb/firefox-health-report-understand-your-browser-perf
lockPref("datareporting.healthreport.uploadEnabled",                false);

// Disable collection of the data (the healthreport.sqlite* files)
lockPref("datareporting.healthreport.service.enabled",              false);

// https://gecko.readthedocs.org/en/latest/toolkit/components/telemetry/telemetry/preferences.html
lockPref("datareporting.policy.dataSubmissionEnabled",              false);

// Disable heartbeat
// https://wiki.mozilla.org/Advocacy/heartbeat
lockPref("browser.selfsupport.url",         "");

EOF
dch -a "Disable browser pings and health reports."

cat << EOF >>debian/vendor.js.in
// Disable web notifications
lockPref("dom.webnotifications.enabled",            false);

EOF
dch -a "Disable web nofitications."

cat << EOF >>debian/vendor.js.in
// Display an error message indicating the entered information is not a valid URL
// http://kb.mozillazine.org/Keyword.enabled#Caveats
lockPref("keyword.enabled",         false);

EOF
dch -a "Display an error if URL is invalid."

cat << EOF >>debian/vendor.js.in
// Don't try to guess URLs
// http://www-archive.mozilla.org/docs/end-user/domain-guessing.html
lockPref("browser.fixup.alternate.enabled",         false);

EOF
dch -a "Disable domain guessing."

cat << EOF >>debian/vendor.js.in
// Never try to use flash
lockPref("plugin.state.flash",              0);

EOF
dch -a "Don't try to use flash."

cat << EOF >>debian/vendor.js.in
// http://forums.mozillazine.org/viewtopic.php?p=13845077&sid=28af2622e8bd8497b9113851676846b1#p13845077
lockPref("media.gmp-provider.enabled",            false);
// https://support.mozilla.org/en-US/kb/how-stop-firefox-making-automatic-connections#w_media-capabilities
lockPref("media.gmp-gmpopenh264.enabled",               false);
lockPref("media.gmp-manager.url",               "");

EOF
dch -a "Disable OpenH264 codec."

cat << EOF >>debian/vendor.js.in
// https://wiki.mozilla.org/Security/Reviews/Firefox6/ReviewNotes/telemetry
lockPref("toolkit.telemetry.enabled",               false);
// https://gecko.readthedocs.org/en/latest/toolkit/components/telemetry/telemetry/preferences.html
lockPref("toolkit.telemetry.unified",               false);
// https://wiki.mozilla.org/Telemetry/Experiments
lockPref("experiments.supported",           false);
lockPref("experiments.enabled",             false);

EOF
dch -a "Disable telemetry."

cat << EOF >>debian/vendor.js.in
// https://blog.mozilla.org/addons/how-to-turn-off-add-on-updates/
pref("extensions.update.enabled",               true);

EOF
dch -a "Enable automatic add-on updates."

cat << EOF >>debian/vendor.js.in
// https://web.nvd.nist.gov/view/vuln/detail?vulnId=CVE-2015-2743
lockPref("pdfjs.disabled",          true);

EOF
dch -a "Disable build-in PDF viewer."

cat << EOF >>debian/vendor.js.in
// Disable 3DES
lockPref("security.ssl3.dhe_dss_des_ede3_sha",              false);
lockPref("security.ssl3.dhe_rsa_des_ede3_sha",              false);
lockPref("security.ssl3.ecdh_ecdsa_des_ede3_sha",           false);
lockPref("security.ssl3.ecdh_rsa_des_ede3_sha",             false);
lockPref("security.ssl3.ecdhe_ecdsa_des_ede3_sha",          false);
lockPref("security.ssl3.ecdhe_rsa_des_ede3_sha",            false);
lockPref("security.ssl3.rsa_des_ede3_sha",          false);
lockPref("security.ssl3.rsa_fips_des_ede3_sha",             false);

EOF
dch -a "Disable 3DES; http://en.citizendium.org/wiki/Meet-in-the-middle_attack"

cat << EOF >>debian/vendor.js.in
// Prevent logjamming.
lockPref("security.ssl3.dhe_rsa_camellia_256_sha",          false);
lockPref("security.ssl3.dhe_rsa_aes_256_sha",               false);

EOF
dch -a "Stop logjamming attacks."

cat << EOF >>debian/vendor.js.in
// Disable DSA.
lockPref("security.ssl3.dhe_dss_aes_128_sha",               false);
lockPref("security.ssl3.dhe_dss_aes_256_sha",               false);
lockPref("security.ssl3.dhe_dss_camellia_128_sha",          false);
lockPref("security.ssl3.dhe_dss_camellia_256_sha",          false);

EOF
dch -a "Disable DSA ciphers."

cat << EOF >>debian/vendor.js.in
// Disable null ciphers.
lockPref("security.ssl3.rsa_null_sha",              false);
lockPref("security.ssl3.rsa_null_md5",              false);
lockPref("security.ssl3.ecdhe_rsa_null_sha",                false);
lockPref("security.ssl3.ecdhe_ecdsa_null_sha",              false);
lockPref("security.ssl3.ecdh_rsa_null_sha",         false);
lockPref("security.ssl3.ecdh_ecdsa_null_sha",               false);

EOF
dch -a "Disable null ciphers."

cat << EOF >>debian/vendor.js.in
// Disable RC4.
lockPref("security.ssl3.ecdh_ecdsa_rc4_128_sha",            false);
lockPref("security.ssl3.ecdh_rsa_rc4_128_sha",              false);
lockPref("security.ssl3.ecdhe_ecdsa_rc4_128_sha",           false);
lockPref("security.ssl3.ecdhe_rsa_rc4_128_sha",             false);
lockPref("security.ssl3.rsa_rc4_128_md5",           false);
lockPref("security.ssl3.rsa_rc4_128_sha",           false);
lockPref("security.tls.unrestricted_rc4_fallback",          false);

EOF
dch -a "Disable RC4."

cat << EOF >>debian/vendor.js.in
// Disable 40 bit
lockPref("security.ssl3.rsa_rc4_40_md5",            false);
lockPref("security.ssl3.rsa_rc2_40_md5",            false);

// Disable 56 bit
lockPref("security.ssl3.rsa_1024_rc4_56_sha",               false);

// Disable 128 bit
lockPref("security.ssl3.rsa_camellia_128_sha",              false);
lockPref("security.ssl3.ecdhe_rsa_aes_128_sha",             false);
lockPref("security.ssl3.ecdhe_ecdsa_aes_128_sha",           false);
lockPref("security.ssl3.ecdh_rsa_aes_128_sha",              false);
lockPref("security.ssl3.ecdh_ecdsa_aes_128_sha",            false);
lockPref("security.ssl3.dhe_rsa_camellia_128_sha",          false);
lockPref("security.ssl3.dhe_rsa_aes_128_sha",               false);

// But enable ECDHE with more than 128 bits
lockPref("security.ssl3.ecdhe_rsa_aes_256_sha",         true);
lockPref("security.ssl3.ecdhe_ecdsa_aes_256_sha",               true);

// Fallbacks for compatibility
lockPref("security.ssl3.rsa_aes_256_sha",               true);
lockPref("security.ssl3.rsa_aes_128_sha",               true);

EOF
dch -a "Disable 40-128 bit encryption." 

cat << EOF >>debian/vendor.js.in
// disable SSLv3
lockPref("security.enable_ssl3",                false);
lockPref("security.ssl3.ecdh_rsa_aes_256_sha",          false);
lockPref("security.ssl3.ecdh_ecdsa_aes_256_sha",                false);
lockPref("security.ssl3.rsa_camellia_256_sha",          false);

EOF
dch -a "Disable SSLv3"

cat << EOF >>debian/vendor.js.in
lockPref("security.ssl3.ecdhe_ecdsa_aes_128_gcm_sha256",                true);
lockPref("security.ssl3.ecdhe_rsa_aes_128_gcm_sha256",          true);

EOF
dch -a "Enable GCM."

cat << EOF >>debian/vendor.js.in
lockPref("security.tls.version.min",            1);
lockPref("security.tls.version.max",            3);

EOF
dch -a "TLS minimum and maximums."

cat << EOF >>debian/vendor.js.in
// https://blog.mozilla.org/security/2012/10/11/click-to-play-plugins-blocklist-style/
lockPref("plugins.click_to_play",               true);

EOF
dch -a "Enable click-to-play."

cat << EOF >>debian/vendor.js.in
lockPref("browser.newtabpage.enhanced",         false);
lockPref("browser.newtab.preload",              false);
lockPref("browser.newtabpage.directory.ping",           "");
lockPref("browser.newtabpage.directory.source",         "data:text/plain,{}");

EOF
dch -a "Disable new-tab tile ads and preloading."

cat << EOF >>debian/vendor.js.in
// https://support.mozilla.org/en-US/kb/save-web-pages-later-pocket-firefox
lockPref("browser.pocket.enabled",              false);

EOF
dch -a "Disable pocket."

cat << EOF >>debian/vendor.js.in
// https://wiki.mozilla.org/Loop
lockPref("loop.enabled",              false);

EOF
dch -a "Disable firefox hello."

cat << EOF >>debian/vendor.js.in
// https://www.mozilla.org/en-US/firefox/39.0/releasenotes/
// https://wiki.mozilla.org/Security/Application_Reputation
lockPref("browser.safebrowsing.downloads.remote.enabled",       false);

EOF
dch -a "Disable safe browsing download lookups."

cat << EOF >>debian/vendor.js.in
// https://support.mozilla.org/en-US/kb/how-stop-firefox-making-automatic-connections#w_auto-update-checking
lockPref("browser.search.update",               false);
// https://support.mozilla.org/en-US/kb/how-stop-firefox-making-automatic-connections#w_mozilla-content
lockPref("browser.aboutHomeSnippets.updateUrl",         "");
// https://support.mozilla.org/en-US/kb/how-stop-firefox-making-automatic-connections#w_speculative-pre-connections
lockPref("network.http.speculative-parallel-limit",             0);
// http://kb.mozillazine.org/Browser.search.suggest.enabled
lockPref("browser.search.suggest.enabled",              false);

EOF
dch -a "Disable some futher automatic connections."

cat << EOF >>debian/vendor.js.in
lockPref("network.prefetch-next",           false);
lockPref("network.dns.disableprefetch",             true);
lockPref("network.dns.disableprefetchFromHTTPS",            true);
// https://wiki.mozilla.org/Privacy/Reviews/Necko
lockPref("network.predictor.enabled",           false);

EOF
dch -a "Disable link and DNS prefetching."

cat << EOF >>debian/vendor.js.in
// https://bugzilla.mozilla.org/show_bug.cgi?id=855326
lockPref("security.csp.experimentalEnabled",            true);
// CSP https://developer.mozilla.org/en-US/docs/Web/Security/CSP/Introducing_Content_Security_Policy
lockPref("security.csp.enable",         true);

EOF
dch -a "Enable Content Security Policy."

cat << EOF >>debian/vendor.js.in
lockPref("privacy.clearOnShutdown.downloads",           true);
lockPref("browser.download.manager.retention",          0);

EOF
dch -a "Forget download history on shutdown."

cat << EOF >>debian/vendor.js.in
lockPref("signon.rememberSignons",              false);
lockPref("security.ask_for_password",           0);

EOF
dch -a "Don't offer to remember usernames and passwords."

cat << EOF >>debian/vendor.js.in
// https://wiki.mozilla.org/Privacy/Reviews/New_Tab
lockPref("browser.newtabpage.enabled",          false);
// https://support.mozilla.org/en-US/kb/new-tab-page-show-hide-and-customize-top-sites#w_how-do-i-turn-the-new-tab-page-off
lockPref("browser.newtab.url",          "about:blank");

EOF
dch -a "Blank new tab."

cat << EOF >>debian/vendor.js.in
// http://dbaron.org/mozilla/visited-privacy
lockPref("layout.css.visited_links_enabled",            false);

EOF
dch -a "Privacy for visited links."

# search plugins
rm -f browser/locales/en-US/searchplugins/*.xml
cp "$basedir"/data/searchplugins/* browser/locales/en-US/searchplugins -a
cat << EOF > browser/locales/en-US/searchplugins/list.txt
duckduckgo
disconnectme
ixquick
startpage
creativecommons
wikipedia
EOF

cat << EOF >>debian/vendor.js.in
// DDG as default search engine
defaultlockPref("browser.search.defaultenginename",              "DuckDuckGo");
EOF

# patches
for patchfile in $(ls "$basedir"/data/patches/)
do
	patch --verbose -p1 < "$basedir"/data/patches/"$patchfile"
done

# Branding/Names
cat << EOF >> browser/confvars.sh
# PureBrowser settings
MOZ_APP_VENDOR=PURISM
MOZ_APP_VERSION=38.4esr-1
MOZ_APP_PROFILE=mozilla/purebrowser
MOZ_PAY=0
MOZ_SERVICES_HEALTHREPORT=0
MOZ_SERVICES_HEALTHREPORTER=0
MOZ_SERVICES_FXACCOUNTS=0
MOZ_SERVICES_METRICS=0
MOZ_DATA_REPORTING=0
MOZ_SERVICES_SYNC=0
MOZ_DEVICES=0
MOZ_ANDROID_GOOGLE_PLAY_SERVICES=0
EOF

sed 's/mozilla-esr/purism-esr/' -i browser/confvars.sh

sed -e 's/designed/adapted from Mozilla Firefox/g' \
    -e 's/Make a donation/Buy a Librem/g' \
    -e 's/global community/small company/g' \
    -e 's/working together to keep the Web open, public and accessible to all/devoted to defending privacy and freedom rights for users/g' \
    -i browser/locales/en-US/chrome/browser/aboutDialog.dtd

sed -e 's/Mozilla/Purism/g' \
    -e 's/Mozilla Firefox/Purism PureBrowser/g' \
    -e 's/Mozilla Corporation/Purism LLC/g' \
    -e 's/https:\/\/www.mozilla.org/https:\/\/puri.sm/g' \
    -i browser/branding/nightly/branding.nsi browser/branding/aurora/branding.nsi browser/branding/official/branding.nsi browser/branding/unofficial/branding.nsi

# change the name of the app
sed -e 's/iceweasel/purebrowser/g' -i debian/control.in debian/changelog
sed -e "s_^Maintainer.*_Maintainer: PureOS GNU/Linux developers <dev@puri.sm>_g" \
    -i debian/control.in
sed -e "s/^Conflicts:/Conflicts: iceweasel,/g" -i debian/control.in
sed -e "s/Provides:/Provides: iceweasel,/g" -i debian/control.in
sed -e "/Breaks/ a\
        Replaces: iceweasel" -i debian/control.in
sed -e "s_^Maintainer.*_Maintainer: $DEBFULLNAME <$DEBEMAIL>_g" -i debian/control.in

echo "Refreshing control file."
debian/rules debian/control
touch -d "yesterday" debian/control
debian/rules debian/control
touch configure js/src/configure
# Fix CVE-2009-4029
sed 's/777/755/;' -i toolkit/crashreporter/google-breakpad/Makefile.in
# Fix CVE-2012-3386
/bin/sed 's/chmod a+w/chmod u+w/' -i ./js/src/ctypes/libffi/Makefile.in ./toolkit/crashreporter/google-breakpad/Makefile.in ./toolkit/crashreporter/google-breakpad/src/third_party/glog/Makefile.in || true

./mach generate-addon-sdk-moz-build

# Fix bug when replacing iceweasel
mv debian/browser.preinst.in debian/browser.postinst.in

# Build using debhelper >> 9.
sed -e 's/debhelper (>= 7.2.3)/debhelper (>> 9)/' \
    -i debian/control.in
dch -a "Bumped debhelper to version 9. No changes needed."
dch -a "Converted into PureBrowser."

echo "Building PureBrowser..."
apt-src import purebrowser --here
cd $basedir
apt-src build purebrowser

# the build is done with apt-src because it takes care of generating a
# patch to contain all of the local changes made. this doesn't always
# work, but for the purpose of this package it works very nicely.
