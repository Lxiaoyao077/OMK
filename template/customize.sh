# shellcheck disable=SC2034
SKIPUNZIP=1

SONAME="Oh My Keymint"
SUPPORTED_ABIS="arm64 x64"
MIN_SDK=29

if [ "$BOOTMODE" ] && [ "$KSU" ]; then
  ui_print "- 正在通过 KernelSU 应用安装"
  ui_print "- KernelSU 版本: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
  if [ "$(which magisk)" ]; then
    ui_print "*********************************************************"
    ui_print "! 不支持多重 Root 方案！"
    ui_print "! 请先卸载 Magisk 再安装 Oh My Keymint"
    abort    "*********************************************************"
  fi
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
  ui_print "- 正在通过 Magisk 应用安装"
else
  ui_print "*********************************************************"
  ui_print "! 不支持从 Recovery 安装"
  ui_print "! 请从 KernelSU 或 Magisk 应用安装"
  abort    "*********************************************************"
fi

VERSION=$(grep_prop version "${TMPDIR}/module.prop")
ui_print "- 正在安装 $SONAME $VERSION"

# check architecture
support=false
for abi in $SUPPORTED_ABIS
do
  if [ "$ARCH" == "$abi" ]; then
    support=true
  fi
done
if [ "$support" == "false" ]; then
  abort "! 不支持的平台: $ARCH"
else
  ui_print "- 设备平台: $ARCH"
fi

# check android
if [ "$API" -lt $MIN_SDK ]; then
  ui_print "! 不支持的 SDK: $API"
  abort "! 最低支持 SDK 为 $MIN_SDK"
else
  ui_print "- 设备 SDK: $API"
fi

ui_print "- 正在解压 verify.sh"
unzip -o "$ZIPFILE" 'verify.sh' -d "$TMPDIR" >&2
if [ ! -f "$TMPDIR/verify.sh" ]; then
  ui_print "*********************************************************"
  ui_print "! 无法解压 verify.sh!"
  ui_print "! 此安装包可能已损坏，请重新下载"
  abort    "*********************************************************"
fi
. "$TMPDIR/verify.sh"
extract "$ZIPFILE" 'customize.sh'  "$TMPDIR/.vunzip"
extract "$ZIPFILE" 'verify.sh'     "$TMPDIR/.vunzip"

ui_print "- 正在解压模块文件"
rm -f "$MODPATH/action.sh"
extract "$ZIPFILE" 'module.prop'     "$MODPATH"
extract "$ZIPFILE" 'post-fs-data.sh' "$MODPATH"
extract "$ZIPFILE" 'service.sh'      "$MODPATH"
extract "$ZIPFILE" 'sepolicy.rule'   "$MODPATH"
extract "$ZIPFILE" 'daemon'          "$MODPATH"
extract "$ZIPFILE" 'daemon-injector' "$MODPATH"
extract "$ZIPFILE" 'injector.toml'   "$MODPATH"
extract "$ZIPFILE" 'keybox.xml'      "$MODPATH"
rm -rf "$MODPATH/webroot"
unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >&2
[ -f "$MODPATH/webroot/index.html" ] || abort "! 缺少 webroot/index.html"
[ -f "$MODPATH/webroot/config.json" ] || abort "! 缺少 webroot/config.json"
chmod 755 "$MODPATH/daemon" "$MODPATH/daemon-injector" \
  "$MODPATH/post-fs-data.sh" "$MODPATH/service.sh"


if [ "$ARCH" = "x64" ] || [ "$ARCH" = "x86_64" ]; then
  ui_print "- 使用内置 x64 二进制文件"
  BINDIR="$MODPATH/libs/x86_64"
  extract "$ZIPFILE" 'libs/x86_64/keymint' "$MODPATH"
  extract "$ZIPFILE" 'libs/x86_64/inject'  "$MODPATH"
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "arm64-v8a" ]; then
  ui_print "- 使用内置 arm64 二进制文件"
  BINDIR="$MODPATH/libs/arm64-v8a"
  extract "$ZIPFILE" 'libs/arm64-v8a/keymint' "$MODPATH"
  extract "$ZIPFILE" 'libs/arm64-v8a/inject'  "$MODPATH"
else
  abort "! 不支持的平台: $ARCH"
fi

[ -f "$BINDIR/keymint" ] || abort "! Missing $BINDIR/keymint"
[ -f "$BINDIR/inject" ] || abort "! Missing $BINDIR/inject"
chmod 755 "$BINDIR/keymint" "$BINDIR/inject"

CONFIG_DIR=/data/adb/omk
mkdir -p "$CONFIG_DIR"
rm -f "$CONFIG_DIR/restart.keymint" "$CONFIG_DIR/restart.injector" "$CONFIG_DIR/restart.all"
rm -f "$CONFIG_DIR/keymint" "$CONFIG_DIR/inject" "$CONFIG_DIR/injector" # clean up old hot-update binaries

if [ ! -f "$CONFIG_DIR/omkdata" ]; then
  ln -s /data/misc/keystore/omk "$CONFIG_DIR/omkdata"
fi
